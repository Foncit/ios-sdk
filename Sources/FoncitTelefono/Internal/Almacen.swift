import Foundation
import Security

/// Datos del teléfono guardados en el celular. El token y las extensiones (con su contraseña SIP) van en el Llavero;
/// lo demás en UserDefaults. Se guardan para conectar al despertar por un aviso aunque la app esté cerrada.
enum Almacen {
    private static let servicio = "com.foncit.telefono"
    private static let preferencias = UserDefaults(suiteName: "foncit_telefono") ?? .standard

    /// Token del usuario en Foncit (TelefonoMovilWS)
    static var token: String? {
        get { leerLlavero("token") }
        set { guardarLlavero("token", newValue) }
    }

    /// Usuario de la plataforma dueño del token (si la app cambia de usuario se borra todo)
    static var usuario: String? {
        get { preferencias.string(forKey: "usuario") }
        set { preferencias.set(newValue, forKey: "usuario") }
    }

    /// Ambiente de Foncit para conectarse aunque la app esté cerrada
    static var ambiente: String? {
        get { preferencias.string(forKey: "ambiente") }
        set { preferencias.set(newValue, forKey: "ambiente") }
    }

    /// Token VoIP (PushKit) del celular
    static var tokenPush: String? {
        get { preferencias.string(forKey: "token_push") }
        set { preferencias.set(newValue, forKey: "token_push") }
    }

    /// Extensiones móviles del usuario (Usuario, Password, Dominio, Puerto, Extension, Nombre)
    static var telefonos: [[String: Any]]? {
        get {
            guard let texto = leerLlavero("telefonos"), let datos = texto.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: datos)) as? [[String: Any]]
        }
        set {
            guard let lista = newValue, let datos = try? JSONSerialization.data(withJSONObject: lista) else {
                guardarLlavero("telefonos", nil)
                return
            }
            guardarLlavero("telefonos", String(data: datos, encoding: .utf8))
        }
    }

    /// Extensión con la que se marca (su usuario SIP)
    static var seleccionada: String? {
        get { preferencias.string(forKey: "seleccionada") }
        set { preferencias.set(newValue, forKey: "seleccionada") }
    }

    static func borrarTodo() {
        ["usuario", "ambiente", "token_push", "seleccionada"].forEach { preferencias.removeObject(forKey: $0) }
        guardarLlavero("token", nil)
        guardarLlavero("telefonos", nil)
    }

    // MARK: Llavero (disponible después del primer desbloqueo: así sirve cuando un aviso despierta la app)

    private static func consulta(_ clave: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servicio,
         kSecAttrAccount as String: clave]
    }

    private static func leerLlavero(_ clave: String) -> String? {
        var busqueda = consulta(clave)
        busqueda[kSecReturnData as String] = true
        busqueda[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(busqueda as CFDictionary, &resultado) == errSecSuccess, let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    private static func guardarLlavero(_ clave: String, _ valor: String?) {
        SecItemDelete(consulta(clave) as CFDictionary)
        guard let valor = valor, let datos = valor.data(using: .utf8) else { return }
        var nuevo = consulta(clave)
        nuevo[kSecValueData as String] = datos
        nuevo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(nuevo as CFDictionary, nil)
    }
}
