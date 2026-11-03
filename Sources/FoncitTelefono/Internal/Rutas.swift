import Foundation

/// Rutas de los webservices de Foncit por ambiente (las mismas que el SDK de Android y COMPLEMENTOS/WEB_PHONE)
enum Rutas {
    static func telefonoMovil(_ ambiente: Ambiente) -> URL {
        switch ambiente {
        case .produccion: return URL(string: "https://foncit.com/WEBSERVICES/V1/TelefonoMovilWS.php")!
        case .pruebas: return URL(string: "https://stg.foncit.com/WEBSERVICES/V1/TelefonoMovilWS.php")!
        }
    }

    /// Llave de acceso del webservice (TelefonoMovilWS)
    static let llave = "TMV8Q2K4XW9RZ7P"
}
