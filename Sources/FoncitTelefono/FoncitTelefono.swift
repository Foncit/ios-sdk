import Foundation
import PushKit

/**
 Foncit: teléfono móvil para cualquier app iOS.

 Uso:
 ```
 // 1. Al arrancar la app (AppDelegate didFinishLaunching o el init de tu App), ANTES que nada:
 //    activa los avisos de llamada (PushKit). Así suena aunque la app esté cerrada.
 FoncitTelefono.activarAvisos()

 // 2. Cuando ya sabes quién es el usuario: el identificador de su usuario en tu plataforma (ej. AgCuentaUsuario).
 //    El bundle de la app debe estar en Foncit > Complementos > Plataformas (iOS) y el usuario haber llegado de tu panel;
 //    sus extensiones se le asignan desde ese panel.
 FoncitTelefono.configurar(usuario: agCuentaUsuario)

 // 3. En la pantalla: una línea
 FoncitTelefonoPantalla()
 ```
 */
public enum FoncitTelefono {

    /// Usuario de la plataforma (el mismo que manda tu panel en UsuariosExternos)
    static var usuario: String = ""

    static var ajustes: AjustesFoncit { MotorLlamadas.compartido.ajustes }

    /// Estado del teléfono (conexión y llamada) para quien quiera pintar su propia interfaz
    public static var estado: EstadoTelefono { MotorLlamadas.compartido.estado }

    /// Si ya se llamó a configurar
    public static var configurado: Bool { !usuario.isEmpty }

    /**
     Configura el teléfono. Llámalo al abrir la app y cada vez que cambie el usuario.
     - usuario: identificador del usuario en tu plataforma
     - ajustes: ambiente y colores (AjustesFoncit)
     */
    public static func configurar(usuario: String, ajustes: AjustesFoncit = AjustesFoncit()) {
        MotorLlamadas.compartido.ajustes = ajustes
        /** Otro usuario en este celular: se olvida el token y las extensiones del anterior */
        if Almacen.usuario != usuario {
            if !(Almacen.usuario ?? "").isEmpty { MotorLlamadas.compartido.apagar() }
            let tokenPush = Almacen.tokenPush
            Almacen.borrarTodo()
            Almacen.tokenPush = tokenPush
            Almacen.usuario = usuario
        }
        self.usuario = usuario
        Almacen.ambiente = ajustes.ambiente.rawValue
        AvisosVoip.compartido.activar()
        /** Si el token VoIP ya existía, el celular se registra con este usuario */
        if Almacen.tokenPush != nil { Task { await ApiFoncit.registrarDispositivo() } }
    }

    /**
     Activa los avisos de llamada (PushKit). Llámalo al arrancar la app, siempre, antes de cualquier otra cosa:
     cuando iOS abre la app por un aviso de llamada, el aviso se entrega aquí. Usa el usuario guardado de la última vez.
     */
    public static func activarAvisos() {
        restaurar()
        AvisosVoip.compartido.activar()
    }

    /// Con la app cerrada (la abrió un aviso) todavía no se llamó a configurar: se usan los datos guardados.
    /// Regresa true si hay usuario guardado
    @discardableResult
    static func restaurar() -> Bool {
        if usuario.isEmpty {
            usuario = Almacen.usuario ?? ""
            let ambiente = Ambiente(rawValue: Almacen.ambiente ?? "") ?? .produccion
            MotorLlamadas.compartido.ajustes.ambiente = ambiente
        }
        return !usuario.isEmpty
    }

    /// Cambia el tema o los colores al momento (ej. cuando la app pasa a modo oscuro o cambia su color)
    public static func cambiarTema(_ ajustes: AjustesFoncit) {
        MotorLlamadas.compartido.ajustes = ajustes
    }

    /// Conecta el teléfono (lo hace solo la pantalla; úsalo si pintas tu propia interfaz)
    public static func iniciar() {
        guard configurado else { return }
        Task { await MotorLlamadas.compartido.conectar() }
    }

    /// Elige con cuál de sus extensiones se marca (su usuario SIP, ExtensionTelefono.usuario). Todas siguen recibiendo llamadas
    public static func seleccionarExtension(_ usuario: String) {
        guard configurado else { return }
        MotorLlamadas.compartido.seleccionar(usuario)
    }

    /// Marca un número (sale en la pantalla de llamadas del sistema)
    public static func llamar(_ numero: String) {
        guard configurado else { return }
        let limpio = numero.filter { $0.isNumber || $0 == "+" || $0 == "*" || $0 == "#" }
        guard !limpio.isEmpty, MotorLlamadas.compartido.asegurarCore() != nil else { return }
        LlamadasSistema.compartido.llamar(limpio)
    }

    /// Al cerrar sesión en tu app: deja de recibir llamadas en este celular y borra los datos del teléfono
    public static func cerrarSesion() {
        guard configurado else { return }
        Task { @MainActor in
            await ApiFoncit.quitarDispositivo()
            MotorLlamadas.compartido.apagar()
            let tokenPush = Almacen.tokenPush
            Almacen.borrarTodo()
            Almacen.tokenPush = tokenPush
            usuario = ""
        }
    }
}

/// Avisos VoIP (PushKit): Foncit los manda por Apple cuando entra una llamada a una extensión del usuario.
/// El token se guarda en Foncit (registrarDispositivo) y cada aviso se muestra de una vez en CallKit mientras la línea se conecta.
final class AvisosVoip: NSObject, PKPushRegistryDelegate {
    static let compartido = AvisosVoip()
    private var registro: PKPushRegistry?

    func activar() {
        guard registro == nil else { return }
        let nuevo = PKPushRegistry(queue: .main)
        nuevo.delegate = self
        nuevo.desiredPushTypes = [.voIP]
        registro = nuevo
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        let cambio = Almacen.tokenPush != token
        Almacen.tokenPush = token
        ApiFoncit.registro.info("Token de avisos recibido (ios, usuario guardado: \(FoncitTelefono.restaurar()))")
        if cambio, FoncitTelefono.restaurar() { Task { await ApiFoncit.registrarDispositivo() } }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        Task { await ApiFoncit.quitarDispositivo() }
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }
        let datos = payload.dictionaryPayload["foncit"] as? [String: Any] ?? [:]
        let conUsuario = FoncitTelefono.restaurar()
        ApiFoncit.registro.info("Aviso de llamada recibido (usuario guardado: \(conUsuario))")
        /** iOS exige mostrar la llamada en CallKit en cada aviso VoIP, antes de terminar */
        LlamadasSistema.compartido.avisoEntrante(
            numero: ApiFoncit.texto(datos["numero"]),
            nombre: ApiFoncit.texto(datos["nombre"]),
            conUsuario: conUsuario,
            alTerminar: completion
        )
        if conUsuario { MotorLlamadas.compartido.despertar() }
    }
}
