import Foundation
import CallKit
import AVFoundation
import linphonesw

/// Llamadas en la pantalla del sistema (CallKit): timbre, pantalla bloqueada, audio y botones del sistema.
/// Una llamada de Linphone se liga con su UUID de CallKit por su Call-ID.
/// Con la app cerrada, el aviso VoIP (PushKit) llega antes que la llamada: se muestra de una vez (iOS lo exige) y queda "pendiente";
/// al llegar la llamada de Linphone se liga a esa misma y, si ya la contestaron o rechazaron, se hace en ese momento.
/// Todo corre en el hilo principal.
final class LlamadasSistema: NSObject, CXProviderDelegate {
    static let compartido = LlamadasSistema()

    private let proveedor: CXProvider
    private let controlador = CXCallController()
    /// Call-ID de Linphone -> UUID de CallKit
    private var uuids: [String: UUID] = [:]
    /// Llamada mostrada por un aviso que todavía no llega por Linphone
    private var pendiente: UUID?
    private var contestarPendiente = false
    private var rechazarPendiente = false
    /// Las que colgó el usuario (ya se le avisó a CallKit)
    private var colgadas: Set<UUID> = []

    private override init() {
        let configuracion = CXProviderConfiguration()
        configuracion.supportsVideo = false
        configuracion.maximumCallGroups = 1
        configuracion.maximumCallsPerCallGroup = 1
        configuracion.supportedHandleTypes = [.phoneNumber, .generic]
        configuracion.includesCallsInRecents = true
        proveedor = CXProvider(configuration: configuracion)
        super.init()
        proveedor.setDelegate(self, queue: nil)
    }

    private func actualizacion(numero: String, nombre: String) -> CXCallUpdate {
        let actualizacion = CXCallUpdate()
        let valor = numero.isEmpty ? Textos.t("foncit_desconocido") : numero
        actualizacion.remoteHandle = CXHandle(type: numero.isEmpty ? .generic : .phoneNumber, value: valor)
        actualizacion.localizedCallerName = nombre.isEmpty ? valor : nombre
        actualizacion.hasVideo = false
        actualizacion.supportsHolding = true
        actualizacion.supportsDTMF = true
        actualizacion.supportsGrouping = false
        actualizacion.supportsUngrouping = false
        return actualizacion
    }

    private func uuidDe(_ call: Call) -> UUID? {
        uuids[call.callLog?.callId ?? ""]
    }

    private func llamadaDe(_ uuid: UUID) -> Call? {
        guard let id = uuids.first(where: { $0.value == uuid })?.key else { return nil }
        return MotorLlamadas.compartido.llamadaDe(id: id)
    }

    // MARK: Avisos y llamadas de Linphone

    /// Aviso VoIP con la app cerrada o en segundo plano: se muestra la llamada antes de que llegue (iOS lo exige en cada aviso)
    func avisoEntrante(numero: String, nombre: String, conUsuario: Bool, alTerminar: @escaping () -> Void) {
        let uuid = UUID()
        let yaHayLlamada = MotorLlamadas.compartido.llamadaActual() != nil || pendiente != nil
        let valida = conUsuario && !yaHayLlamada
        if valida {
            pendiente = uuid
            contestarPendiente = false
            rechazarPendiente = false
        }
        proveedor.reportNewIncomingCall(with: uuid, update: actualizacion(numero: numero, nombre: nombre)) { [weak self] error in
            alTerminar()
            guard let self = self else { return }
            if error != nil {
                if self.pendiente == uuid { self.pendiente = nil }
                return
            }
            /** Sin usuario o con otra llamada: iOS pide mostrarla de todos modos; se termina de una vez */
            if !valida {
                self.proveedor.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                return
            }
            /** Si en 25 segundos no llega la llamada (ya la contestó otro o colgaron) se quita */
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                guard let self = self, self.pendiente == uuid else { return }
                self.pendiente = nil
                self.proveedor.reportCall(with: uuid, endedAt: Date(), reason: .unanswered)
            }
        }
    }

    /// Llegó la llamada por Linphone: se liga a la del aviso o se muestra como nueva
    func llamadaEntrante(_ call: Call) {
        let id = call.callLog?.callId ?? UUID().uuidString
        let numero = call.remoteAddress?.username ?? ""
        let nombre = call.remoteAddress?.displayName ?? ""
        if let uuid = pendiente {
            pendiente = nil
            uuids[id] = uuid
            proveedor.reportCall(with: uuid, updated: actualizacion(numero: numero, nombre: nombre))
            if rechazarPendiente {
                MotorLlamadas.compartido.colgar(call)
            } else if contestarPendiente {
                MotorLlamadas.compartido.contestar(call)
            }
            return
        }
        let uuid = UUID()
        uuids[id] = uuid
        proveedor.reportNewIncomingCall(with: uuid, update: actualizacion(numero: numero, nombre: nombre)) { error in
            if error != nil { MotorLlamadas.compartido.colgar(call) }
        }
    }

    func llamadaConectada(_ call: Call) {
        guard call.dir == .Outgoing, let uuid = uuidDe(call) else { return }
        proveedor.reportOutgoingCall(with: uuid, connectedAt: Date())
    }

    func llamadaTerminada(_ call: Call) {
        let id = call.callLog?.callId ?? ""
        guard let uuid = uuids.removeValue(forKey: id) else { return }
        if colgadas.remove(uuid) != nil { return }
        let razon: CXCallEndedReason = (call.dir == .Incoming && call.duration == 0) ? .unanswered : .remoteEnded
        proveedor.reportCall(with: uuid, endedAt: Date(), reason: razon)
    }

    // MARK: Lo que pide la app (pasa por CallKit para que el sistema lo sepa)

    private func pedir(_ accion: CXAction) {
        controlador.request(CXTransaction(action: accion)) { error in
            if let error = error { ApiFoncit.registro.warning("CallKit: \(error.localizedDescription)") }
        }
    }

    private func uuidActual() -> UUID? {
        if let call = MotorLlamadas.compartido.llamadaActual(), let uuid = uuidDe(call) { return uuid }
        return pendiente
    }

    func llamar(_ numero: String) {
        pedir(CXStartCallAction(call: UUID(), handle: CXHandle(type: .phoneNumber, value: numero)))
    }

    func contestar() {
        if let uuid = uuidActual() { pedir(CXAnswerCallAction(call: uuid)) }
    }

    func colgar() {
        if let uuid = uuidActual() {
            pedir(CXEndCallAction(call: uuid))
        } else if let call = MotorLlamadas.compartido.llamadaActual() {
            MotorLlamadas.compartido.colgar(call)
        }
    }

    func silenciar() {
        guard let uuid = uuidActual() else { return }
        pedir(CXSetMutedCallAction(call: uuid, muted: !(MotorLlamadas.compartido.estado.llamada?.silenciada ?? false)))
    }

    func espera() {
        guard let uuid = uuidActual() else { return }
        pedir(CXSetHeldCallAction(call: uuid, onHold: MotorLlamadas.compartido.estado.llamada?.estado != .enEspera))
    }

    // MARK: CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        MotorLlamadas.compartido.core?.calls.forEach { MotorLlamadas.compartido.colgar($0) }
        uuids.removeAll()
        pendiente = nil
        colgadas.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let call = MotorLlamadas.compartido.marcar(action.handle.value) else {
            action.fail()
            return
        }
        uuids[call.callLog?.callId ?? UUID().uuidString] = action.callUUID
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let call = llamadaDe(action.callUUID) {
            MotorLlamadas.compartido.contestar(call)
        } else if pendiente == action.callUUID {
            /** Aún no llega por Linphone: se contesta en cuanto llegue */
            contestarPendiente = true
            MotorLlamadas.compartido.core?.configureAudioSession()
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        colgadas.insert(action.callUUID)
        if let call = llamadaDe(action.callUUID) {
            MotorLlamadas.compartido.colgar(call)
        } else if pendiente == action.callUUID {
            /** Aún no llega por Linphone: se rechaza en cuanto llegue */
            rechazarPendiente = true
            colgadas.remove(action.callUUID)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let call = llamadaDe(action.callUUID) { MotorLlamadas.compartido.silenciar(call, action.isMuted) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        if let call = llamadaDe(action.callUUID) { MotorLlamadas.compartido.espera(call, action.isOnHold) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        action.digits.forEach { MotorLlamadas.compartido.tono($0) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        MotorLlamadas.compartido.audioActivado(true)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        MotorLlamadas.compartido.audioActivado(false)
    }
}
