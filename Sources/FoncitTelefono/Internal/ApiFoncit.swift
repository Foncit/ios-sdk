import Foundation
import os

/// Token de Foncit inválido o el usuario ya no tiene acceso
struct TokenInvalido: Error {
    var mensaje: String?
}

/// Webservice del teléfono móvil (TelefonoMovilWS). El token se pide con el usuario de la plataforma y el bundle de la app
/// (iniciarUsuario); el bundle debe estar en Foncit > Complementos > Plataformas como "iOS".
enum ApiFoncit {
    static let registro = Logger(subsystem: "com.foncit.telefono", category: "FoncitTelefono")

    static func token(forzarNuevo: Bool = false) async throws -> String {
        if !forzarNuevo, let guardado = Almacen.token, !guardado.isEmpty { return guardado }
        let usuario = FoncitTelefono.usuario
        guard !usuario.isEmpty else { throw TokenInvalido() }
        let respuesta = try await enviar("iniciarUsuario", [
            "IdExterno": usuario,
            "Paquete": Bundle.main.bundleIdentifier ?? "",
            "Plataforma": "ios"
        ], token: nil).1
        guard (respuesta["status"] as? Bool) == true, let nuevo = respuesta["Token"] as? String, !nuevo.isEmpty else {
            throw TokenInvalido(mensaje: respuesta["mensaje"] as? String)
        }
        Almacen.token = nuevo
        return nuevo
    }

    /// POST a TelefonoMovilWS; regresa el código HTTP y el JSON
    private static func enviar(_ solicitud: String, _ datos: [String: Any], token: String?) async throws -> (Int, [String: Any]) {
        var peticion = URLRequest(url: Rutas.telefonoMovil(FoncitTelefono.ajustes.ambiente))
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = 20
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token { peticion.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var cuerpo = datos
        cuerpo["llaveAcceso"] = Rutas.llave
        cuerpo["solicitud"] = solicitud
        cuerpo["Idioma"] = Locale.current.languageCode == "en" ? "en" : "es"
        peticion.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        let (datosRespuesta, respuesta) = try await URLSession.shared.data(for: peticion)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: datosRespuesta)) as? [String: Any] ?? [:]
        return (codigo, json)
    }

    private static func peticion(_ solicitud: String, _ datos: [String: Any] = [:], reintentar: Bool = true) async throws -> [String: Any] {
        let token = try await token()
        let respuesta = try await enviar(solicitud, datos, token: token)
        if respuesta.0 == 401 {
            /** Token revocado: se pide uno nuevo una vez */
            Almacen.token = nil
            if reintentar {
                _ = try await self.token(forzarNuevo: true)
                return try await peticion(solicitud, datos, reintentar: false)
            }
            throw TokenInvalido(mensaje: respuesta.1["mensaje"] as? String)
        }
        return respuesta.1
    }

    /// Extensiones móviles del usuario, las actuales de Foncit. Se guardan para conectar al despertar;
    /// nil si Foncit no respondió bien (se usan las guardadas)
    static func mostrarTelefonos() async throws -> [[String: Any]]? {
        let respuesta = try await peticion("mostrarTelefono")
        /** Aún no le asignan extensiones: lista vacía (no las guardadas) */
        if (respuesta["SinExtensiones"] as? Int) == 1 {
            Almacen.telefonos = []
            return []
        }
        guard (respuesta["status"] as? Bool) == true else { return nil }
        let telefonos = (respuesta["rrTelefonos"] as? [[String: Any]]) ?? (respuesta["rrTelefono"] as? [String: Any]).map { [$0] }
        guard let lista = telefonos else { return nil }
        Almacen.telefonos = lista
        return lista
    }

    /// Guarda el celular en Foncit (TBL_PBX_DISPOSITIVOS) con su token VoIP para que le avise de las llamadas con la app cerrada.
    /// Se ve en la consola de Xcode: FoncitTelefono
    static func registrarDispositivo() async {
        guard let tokenPush = Almacen.tokenPush, !tokenPush.isEmpty else {
            registro.warning("registrarDispositivo: todavía no hay token de avisos (PushKit)")
            return
        }
        #if DEBUG
        let produccion = 0
        #else
        let produccion = 1
        #endif
        do {
            let respuesta = try await peticion("registrarDispositivo", [
                "Plataforma": "ios",
                "TokenPush": tokenPush,
                "App": Bundle.main.bundleIdentifier ?? "",
                "Produccion": produccion
            ])
            registro.info("registrarDispositivo: \(String(describing: respuesta["status"] ?? false)) \(respuesta["mensaje"] as? String ?? "")")
        } catch {
            registro.warning("registrarDispositivo: \(error.localizedDescription)")
        }
    }

    static func quitarDispositivo() async {
        guard let tokenPush = Almacen.tokenPush else { return }
        _ = try? await peticion("quitarDispositivo", ["TokenPush": tokenPush], reintentar: false)
    }

    static func mostrarLlamadas(pagina: Int = 1) async throws -> [LlamadaReciente] {
        let respuesta = try await peticion("mostrarLlamadas", ["Pagina": pagina])
        let lista = respuesta["rrLlamadas"] as? [[String: Any]] ?? []
        return lista.map { l in
            LlamadaReciente(
                numero: texto(l["Numero"]),
                nombre: texto(l["Nombre"]),
                direccion: texto(l["Direccion"]),
                estatus: texto(l["Estatus"]),
                duracion: Int(texto(l["Duracion"])) ?? 0,
                fecha: texto(l["Fecha"])
            )
        }
    }

    /// Valor del JSON como texto (Foncit puede mandar números como texto o al revés)
    static func texto(_ valor: Any?) -> String {
        switch valor {
        case let cadena as String: return cadena
        case let numero as NSNumber: return numero.stringValue
        default: return ""
        }
    }
}
