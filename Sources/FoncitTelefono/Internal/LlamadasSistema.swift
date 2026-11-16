import Foundation
import CallKit
import AVFoundation
import UIKit
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
    /// Call-ID de las llamadas que iOS no dejó mostrar en su pantalla (No molestar / modo de concentración): se atienden desde la app
    private var sinSistema: Set<String> = []

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
        /** Diagnóstico: cómo está el estado cuando llega la llamada de Linphone (log: subsistema de Foncit) */
        ApiFoncit.registro.warning("Llamada entrante de Linphone: aviso pendiente \(self.pendiente != nil, privacy: .public), contestar pendiente \(self.contestarPendiente, privacy: .public), rechazar pendiente \(self.rechazarPendiente, privacy: .public)")
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
        proveedor.reportNewIncomingCall(with: uuid, update: actualizacion(numero: numero, nombre: nombre)) { [weak self] error in
            if let error = error {
                /** Diagnóstico: iOS no dejó mostrar la llamada (No molestar, otra llamada activa, número bloqueado…) */
                ApiFoncit.registro.error("CallKit rechazó la llamada entrante: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.uuids.removeValue(forKey: id)
                    if UIApplication.shared.applicationState == .active {
                        /** Con la app abierta la llamada sigue sonando en la pantalla de la app y se contesta desde ahí, sin CallKit */
                        self.sinSistema.insert(id)
                        ApiFoncit.registro.warning("La llamada se atiende desde la app (sin la pantalla del sistema)")
                    } else {
                        MotorLlamadas.compartido.colgar(call)
                    }
                }
            }
        }
    }

    func llamadaConectada(_ call: Call) {
        guard call.dir == .Outgoing, let uuid = uuidDe(call) else { return }
        proveedor.reportOutgoingCall(with: uuid, connectedAt: Date())
    }

    func llamadaTerminada(_ call: Call) {
        let id = call.callLog?.callId ?? ""
        guard let uuid = uuids.removeValue(forKey: id) else {
            /** No la llevaba CallKit (se atendió o marcó desde la app): la app apaga el audio */
            if !sinSistema.isEmpty {
                sinSistema.removeAll()
                MotorLlamadas.compartido.audioActivado(false)
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            return
        }
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
        let accion = CXStartCallAction(call: UUID(), handle: CXHandle(type: .phoneNumber, value: numero))
        controlador.request(CXTransaction(action: accion)) { [weak self] error in
            guard let error = error else { return }
            /** iOS no dejó iniciar la llamada por su pantalla: se marca directo desde la app */
            ApiFoncit.registro.warning("CallKit no inició la llamada (\(error.localizedDescription, privacy: .public)): se marca desde la app")
            DispatchQueue.main.async { self?.llamarSinSistema(numero) }
        }
    }

    /// Marca sin CallKit: la app activa el audio (lo que haría el sistema) y la llamada se ve en la pantalla de la app
    private func llamarSinSistema(_ numero: String) {
        guard let call = MotorLlamadas.compartido.marcar(numero) else {
            ApiFoncit.registro.error("No se pudo marcar desde la app")
            return
        }
        sinSistema.insert(call.callLog?.callId ?? "")
        try? AVAudioSession.sharedInstance().setActive(true)
        MotorLlamadas.compartido.audioActivado(true)
    }

    func contestar() {
        if let uuid = uuidActual() {
            pedir(CXAnswerCallAction(call: uuid))
        } else if let call = MotorLlamadas.compartido.llamadaActual() {
            /** iOS no mostró esta llamada: se contesta directo y la app activa el audio (lo que haría CallKit) */
            ApiFoncit.registro.warning("Se contesta desde la app (sin CallKit)")
            MotorLlamadas.compartido.contestar(call)
            try? AVAudioSession.sharedInstance().setActive(true)
            MotorLlamadas.compartido.audioActivado(true)
        }
    }

    func colgar() {
        if let uuid = uuidActual() {
            pedir(CXEndCallAction(call: uuid))
        } else if let call = MotorLlamadas.compartido.llamadaActual() {
            MotorLlamadas.compartido.colgar(call)
        }
    }

    func silenciar() {
        guard let uuid = uuidActual() else {
            if let call = MotorLlamadas.compartido.llamadaActual() { MotorLlamadas.compartido.silenciar(call, !call.microphoneMuted) }
            return
        }
        pedir(CXSetMutedCallAction(call: uuid, muted: !(MotorLlamadas.compartido.estado.llamada?.silenciada ?? false)))
    }

    func espera() {
        guard let uuid = uuidActual() else {
            if let call = MotorLlamadas.compartido.llamadaActual() {
                MotorLlamadas.compartido.espera(call, MotorLlamadas.compartido.estado.llamada?.estado != .enEspera)
            }
            return
        }
        pedir(CXSetHeldCallAction(call: uuid, onHold: MotorLlamadas.compartido.estado.llamada?.estado != .enEspera))
    }

    // MARK: CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        ApiFoncit.registro.warning("CallKit reinició el proveedor: se cuelgan las llamadas")
        MotorLlamadas.compartido.core?.calls.forEach { MotorLlamadas.compartido.colgar($0) }
        uuids.removeAll()
        sinSistema.removeAll()
        pendiente = nil
        colgadas.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let call = MotorLlamadas.compartido.marcar(action.handle.value) else {
            ApiFoncit.registro.error("CallKit pidió marcar pero el motor no pudo (sin extensión o número inválido)")
            action.fail()
            return
        }
        uuids[call.callLog?.callId ?? UUID().uuidString] = action.callUUID
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        ApiFoncit.registro.warning("CallKit pidió contestar: ligada a una llamada de Linphone \(self.llamadaDe(action.callUUID) != nil, privacy: .public), es la del aviso \(self.pendiente == action.callUUID, privacy: .public)")
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
        ApiFoncit.registro.warning("CallKit pidió colgar: ligada a una llamada de Linphone \(self.llamadaDe(action.callUUID) != nil, privacy: .public), es la del aviso \(self.pendiente == action.callUUID, privacy: .public)")
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
