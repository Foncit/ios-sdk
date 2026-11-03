import Foundation
import UIKit
import linphonesw

/// Motor de llamadas (Linphone): una cuenta SIP por cada extensión móvil del usuario, por TLS y con voz cifrada (SRTP) si la extensión la tiene.
/// Todas reciben llamadas; se marca desde la seleccionada. Las extensiones salen de Foncit cada vez que conecta (ApiFoncit.mostrarTelefonos):
/// las que ya no existen se quitan y las nuevas se agregan. Se guardan para conectar rápido al despertar por un aviso.
/// El audio y la pantalla del sistema van con CallKit (LlamadasSistema). Todo corre en el hilo principal.
final class MotorLlamadas: ObservableObject {
    static let compartido = MotorLlamadas()

    @Published private(set) var estado = EstadoTelefono()
    /// Ajustes actuales; la pantalla los sigue en vivo (tema y colores)
    @Published var ajustes = AjustesFoncit()

    private(set) var core: Core?
    private var delegado: CoreDelegateStub?

    /// Extensiones actuales (los datos de Foncit) y el estado de registro de cada una por su usuario SIP
    private var telefonos: [[String: Any]] = []
    private var registros: [String: EstadoRegistro] = [:]
    private var mensajeRegistro: String?
    private var observadores: [NSObjectProtocol] = []

    private init() {}

    // MARK: Motor

    /// Crea el motor una sola vez (TLS, SRTP si la extensión lo tiene, CallKit)
    @discardableResult
    func asegurarCore() -> Core? {
        if let core = core { return core }
        do {
            let nuevo = try Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            nuevo.pushNotificationEnabled = false
            /** El timbre, la pantalla bloqueada y el audio los maneja CallKit */
            nuevo.callkitEnabled = true
            /** Voz cifrada (SRTP) cuando la extensión la tiene (media_encryption = sdes); si no, la llamada entra igual sin cifrar */
            try? nuevo.setMediaencryption(newValue: .SRTP)
            nuevo.mediaEncryptionMandatory = false
            nuevo.verifyServerCertificates(yesno: true)
            nuevo.verifyServerCn(yesno: true)
            let delegado = CoreDelegateStub(
                onCallStateChanged: { [weak self] (_: Core, call: Call, state: Call.State, _: String) in
                    self?.cambioLlamada(call, state)
                },
                onAccountRegistrationStateChanged: { [weak self] (_: Core, account: Account, state: RegistrationState, message: String) in
                    self?.cambioRegistro(account, state, message)
                }
            )
            nuevo.addDelegate(delegate: delegado)
            try nuevo.start()
            self.delegado = delegado
            core = nuevo
            observarApp()
            return nuevo
        } catch {
            ApiFoncit.registro.error("No se pudo iniciar el motor de llamadas: \(error.localizedDescription)")
            return nil
        }
    }

    /// En segundo plano iOS cierra la conexión; al volver se registra de nuevo
    private func observarApp() {
        guard observadores.isEmpty else { return }
        let centro = NotificationCenter.default
        observadores.append(centro.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.core?.enterBackground()
        })
        observadores.append(centro.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.core?.enterForeground()
            self?.core?.refreshRegisters()
        })
    }

    private func cambioRegistro(_ account: Account, _ state: RegistrationState, _ message: String) {
        let registro: EstadoRegistro
        switch state {
        case .Ok: registro = .conectado
        case .Progress, .Refreshing: registro = .conectando
        case .Failed: registro = .error
        default: registro = .desconectado
        }
        guard let usuario = account.params?.identityAddress?.username else { return }
        registros[usuario] = registro
        if registro == .error { mensajeRegistro = message }
        publicarExtensiones()
    }

    private func cambioLlamada(_ call: Call, _ state: Call.State) {
        switch state {
        case .IncomingReceived:
            actualizarLlamada(call, .entrante)
            LlamadasSistema.compartido.llamadaEntrante(call)
        case .OutgoingInit, .OutgoingProgress:
            actualizarLlamada(call, .marcando)
        case .OutgoingRinging:
            actualizarLlamada(call, .sonando)
        case .Connected, .StreamsRunning, .Resuming:
            actualizarLlamada(call, .enCurso)
            LlamadasSistema.compartido.llamadaConectada(call)
        case .Paused, .PausedByRemote:
            actualizarLlamada(call, .enEspera)
        case .End, .Error:
            LlamadasSistema.compartido.llamadaTerminada(call)
            if (core?.callsNb ?? 0) == 0 { estado.llamada = nil }
        case .Released:
            if (core?.callsNb ?? 0) == 0 { estado.llamada = nil }
        default:
            break
        }
    }

    private func numeroDe(_ call: Call) -> String { call.remoteAddress?.username ?? "" }
    private func nombreDe(_ call: Call) -> String { call.remoteAddress?.displayName ?? "" }

    private func actualizarLlamada(_ call: Call, _ estadoLlamada: EstadoLlamada) {
        let anterior = estado.llamada
        var inicio: Date?
        if estadoLlamada == .enCurso || estadoLlamada == .enEspera {
            inicio = anterior?.inicio ?? Date().addingTimeInterval(-Double(call.duration))
        }
        estado.llamada = LlamadaActual(
            numero: numeroDe(call),
            nombre: nombreDe(call),
            entrante: call.dir == .Incoming,
            estado: estadoLlamada,
            inicio: inicio,
            silenciada: call.microphoneMuted,
            altavoz: call.outputAudioDevice?.type == .Speaker
        )
    }

    // MARK: Extensiones

    private func usuarioDe(_ telefono: [String: Any]) -> String { ApiFoncit.texto(telefono["Usuario"]) }
    private func dominioDe(_ telefono: [String: Any]) -> String { ApiFoncit.texto(telefono["Dominio"]) }
    private func identidadDe(_ telefono: [String: Any]) -> String { "sip:\(usuarioDe(telefono))@\(dominioDe(telefono))" }

    func cuentaDe(_ usuario: String) -> Account? {
        core?.accountList.first { $0.params?.identityAddress?.username == usuario }
    }

    /// La extensión con la que se marca: la elegida o, si ya no está, la primera
    private func telefonoSeleccionado() -> [String: Any]? {
        telefonos.first { usuarioDe($0) == Almacen.seleccionada } ?? telefonos.first
    }

    /// Pasa a la interfaz las extensiones con su estado; registro, extensión y nombre son los de la seleccionada
    private func publicarExtensiones() {
        let seleccionado = telefonoSeleccionado()
        let usuarioSeleccionado = seleccionado.map { usuarioDe($0) } ?? ""
        estado.extensiones = telefonos.map {
            ExtensionTelefono(
                usuario: usuarioDe($0),
                extensionNumero: ApiFoncit.texto($0["Extension"]),
                nombre: ApiFoncit.texto($0["Nombre"]),
                registro: registros[usuarioDe($0)] ?? .conectando
            )
        }
        let registro: EstadoRegistro = seleccionado == nil ? .desconectado : (registros[usuarioSeleccionado] ?? .conectando)
        estado.seleccionada = usuarioSeleccionado
        estado.extensionNumero = seleccionado.map { ApiFoncit.texto($0["Extension"]) } ?? ""
        estado.nombre = seleccionado.map { ApiFoncit.texto($0["Nombre"]) } ?? ""
        estado.registro = registro
        if registro == .error { estado.mensaje = mensajeRegistro }
    }

    /// Deja en Linphone exactamente las extensiones de la lista: quita las que ya no están y agrega las nuevas (cada una con su contraseña)
    private func configurarCuentas(_ core: Core, _ lista: [[String: Any]]) {
        let nuevos = lista.filter { !usuarioDe($0).isEmpty && !dominioDe($0).isEmpty }
        let identidades = Set(nuevos.map { identidadDe($0) })

        for cuenta in core.accountList where !identidades.contains(cuenta.params?.identityAddress?.asStringUriOnly() ?? "") {
            let usuario = cuenta.params?.identityAddress?.username ?? ""
            let dominio = cuenta.params?.identityAddress?.domain
            core.removeAccount(account: cuenta)
            if let info = core.findAuthInfo(realm: nil, username: usuario, sipDomain: dominio) { core.removeAuthInfo(info: info) }
            registros.removeValue(forKey: usuario)
        }

        let actuales = Set(core.accountList.compactMap { $0.params?.identityAddress?.asStringUriOnly() })
        for telefono in nuevos where !actuales.contains(identidadDe(telefono)) {
            let usuario = usuarioDe(telefono)
            let dominio = dominioDe(telefono)
            let puerto = ApiFoncit.texto(telefono["Puerto"]).isEmpty ? "5061" : ApiFoncit.texto(telefono["Puerto"])
            do {
                let autenticacion = try Factory.Instance.createAuthInfo(username: usuario, userid: "", passwd: ApiFoncit.texto(telefono["Password"]), ha1: "", realm: "", domain: dominio)
                core.addAuthInfo(info: autenticacion)
                let parametros = try core.createAccountParams()
                try parametros.setIdentityaddress(newValue: try Factory.Instance.createAddress(addr: identidadDe(telefono)))
                let servidor = try Factory.Instance.createAddress(addr: "sip:\(dominio):\(puerto)")
                try servidor.setTransport(newValue: .Tls)
                try parametros.setServeraddress(newValue: servidor)
                parametros.registerEnabled = true
                try core.addAccount(account: try core.createAccount(params: parametros))
                registros[usuario] = .conectando
            } catch {
                ApiFoncit.registro.error("No se pudo agregar la extensión \(usuario): \(error.localizedDescription)")
            }
        }

        telefonos = nuevos
        if let seleccionado = telefonoSeleccionado(), let cuenta = cuentaDe(usuarioDe(seleccionado)) { core.defaultAccount = cuenta }
        publicarExtensiones()
    }

    /// Elige con cuál extensión se marca
    func seleccionar(_ usuario: String) {
        guard telefonos.contains(where: { usuarioDe($0) == usuario }) else { return }
        Almacen.seleccionada = usuario
        if let cuenta = cuentaDe(usuario) { core?.defaultAccount = cuenta }
        publicarExtensiones()
    }

    /// Pide a Foncit sus extensiones actuales (si hay red) y las conecta todas (en el hilo principal, como Linphone)
    @MainActor
    func conectar() async {
        guard let core = asegurarCore() else { return }
        if estado.registro != .conectado { estado.registro = .conectando }
        estado.mensaje = nil
        var lista: [[String: Any]]?
        do {
            lista = try await ApiFoncit.mostrarTelefonos() ?? Almacen.telefonos
        } catch let error as TokenInvalido {
            /** Foncit ya no reconoce al usuario: se quitan sus extensiones del celular */
            configurarCuentas(core, [])
            estado.registro = .error
            estado.mensaje = error.mensaje
            estado.sinExtensiones = false
            return
        } catch {
            lista = Almacen.telefonos
        }
        guard let telefonos = lista, !telefonos.isEmpty else {
            configurarCuentas(core, [])
            estado.registro = .error
            estado.sinExtensiones = lista != nil
            return
        }
        estado.sinExtensiones = false
        configurarCuentas(core, telefonos)
        core.refreshRegisters()
        await ApiFoncit.registrarDispositivo()
    }

    /// Llegó un aviso de llamada: se conecta ya con los datos guardados para que la llamada entre
    func despertar() {
        guard let core = asegurarCore() else { return }
        core.enterForeground()
        if let guardados = Almacen.telefonos, !guardados.isEmpty {
            configurarCuentas(core, guardados)
            core.refreshRegisters()
        } else {
            Task { await self.conectar() }
        }
    }

    // MARK: Llamadas (las pide LlamadasSistema, que pasa por CallKit)

    func llamadaDe(id: String) -> Call? {
        core?.calls.first { $0.callLog?.callId == id }
    }

    /// Marca desde la extensión seleccionada; regresa la llamada creada
    func marcar(_ numero: String) -> Call? {
        guard let core = asegurarCore(), let telefono = telefonoSeleccionado() else { return nil }
        do {
            let destino = try Factory.Instance.createAddress(addr: "sip:\(numero)@\(dominioDe(telefono))")
            let parametros = try core.createCallParams(call: nil)
            parametros.mediaEncryption = .SRTP
            if let cuenta = cuentaDe(usuarioDe(telefono)) { parametros.account = cuenta }
            core.configureAudioSession()
            return core.inviteAddressWithParams(addr: destino, params: parametros)
        } catch {
            ApiFoncit.registro.error("No se pudo marcar: \(error.localizedDescription)")
            return nil
        }
    }

    func contestar(_ call: Call) {
        core?.configureAudioSession()
        /** Con el cifrado que trae la llamada (SRTP si la extensión lo tiene) */
        if let parametros = try? core?.createCallParams(call: call) {
            try? call.acceptWithParams(params: parametros)
        } else {
            try? call.accept()
        }
    }

    func colgar(_ call: Call) {
        if call.state == .IncomingReceived { try? call.decline(reason: .Declined) } else { try? call.terminate() }
    }

    func silenciar(_ call: Call, _ silenciada: Bool) {
        call.microphoneMuted = silenciada
        estado.llamada?.silenciada = silenciada
    }

    func espera(_ call: Call, _ enEspera: Bool) {
        if enEspera { try? call.pause() } else { try? call.resume() }
    }

    func tono(_ digito: Character) {
        guard let call = core?.currentCall, let valor = digito.asciiValue else { return }
        try? call.sendDtmf(dtmf: CChar(valor))
    }

    func altavoz() {
        guard let call = core?.currentCall ?? core?.calls.first else { return }
        let actual = call.outputAudioDevice?.type == .Speaker
        let buscado: AudioDevice.Kind = actual ? .Earpiece : .Speaker
        guard let dispositivo = core?.audioDevices.first(where: { $0.type == buscado }) else { return }
        call.outputAudioDevice = dispositivo
        estado.llamada?.altavoz = !actual
    }

    func audioActivado(_ activo: Bool) {
        core?.activateAudioSession(activated: activo)
    }

    func llamadaActual() -> Call? { core?.currentCall ?? core?.calls.first }

    func apagar() {
        if let core = core {
            if let delegado = delegado { core.removeDelegate(delegate: delegado) }
            core.stop()
        }
        core = nil
        delegado = nil
        telefonos = []
        registros = [:]
        mensajeRegistro = nil
        estado = EstadoTelefono()
    }
}
