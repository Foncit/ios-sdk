import Foundation

/// Textos del teléfono (Resources/es.lproj y en.lproj). Con CocoaPods vienen en FoncitTelefono.bundle; con Swift Package en Bundle.module
enum Textos {
    private final class Marca {}

    static let paquete: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let base = Bundle(for: Marca.self)
        if let ruta = base.url(forResource: "FoncitTelefono", withExtension: "bundle"), let paquete = Bundle(url: ruta) {
            return paquete
        }
        return base
        #endif
    }()

    static func t(_ clave: String) -> String {
        NSLocalizedString(clave, tableName: nil, bundle: paquete, value: clave, comment: "")
    }

    static func t(_ clave: String, _ valor: String) -> String {
        String(format: t(clave), valor)
    }
}
