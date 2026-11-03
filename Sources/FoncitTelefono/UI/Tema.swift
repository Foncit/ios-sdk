import SwiftUI

/// Colores del teléfono: los de la app (claro / oscuro, AjustesFoncit) y, lo que no mande, los de Foncit.
/// Se calculan con los ajustes actuales: si la app cambia de tema o de color, se pinta de nuevo al momento.
struct TemaFoncit {
    let oscuro: Bool
    let principal: Color
    let sobrePrincipal: Color
    let fondo: Color
    let superficie: Color
    let superficieVariante: Color
    let texto: Color
    let textoSecundario: Color

    init(ajustes: AjustesFoncit, esquema: ColorScheme) {
        oscuro = ajustes.oscuro ?? (esquema == .dark)
        let app = oscuro ? ajustes.coloresOscuro : ajustes.coloresClaro
        let argbPrincipal = app.principal ?? ajustes.colorPrincipal
        principal = Color(argb: argbPrincipal)
        sobrePrincipal = luminancia(argbPrincipal) > 0.5 ? Color(argb: 0xFF111827) : .white
        if oscuro {
            fondo = Color(argb: app.fondo ?? 0xFF0B1326)
            superficie = Color(argb: app.superficie ?? 0xFF121C32)
            superficieVariante = Color(argb: app.superficieVariante ?? 0xFF182542)
            texto = Color(argb: app.texto ?? 0xFFFFFFFF)
            textoSecundario = Color(argb: app.textoSecundario ?? 0xFF94A3B8)
        } else {
            fondo = Color(argb: app.fondo ?? 0xFFF8F9FA)
            superficie = Color(argb: app.superficie ?? 0xFFFFFFFF)
            superficieVariante = Color(argb: app.superficieVariante ?? 0xFFF3F5F7)
            texto = Color(argb: app.texto ?? 0xFF334155)
            textoSecundario = Color(argb: app.textoSecundario ?? 0xFF8996A4)
        }
    }
}

let verdeFoncit = Color(argb: 0xFF10B981)
let rojoFoncit = Color(argb: 0xFFEF4444)
let ambarFoncit = Color(argb: 0xFFF59E0B)

extension Color {
    /// Color desde ARGB (ej. 0xFFE9791E), igual que en Android
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

private func luminancia(_ argb: UInt32) -> Double {
    func canal(_ valor: UInt32) -> Double {
        let c = Double(valor & 0xFF) / 255
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * canal(argb >> 16) + 0.7152 * canal(argb >> 8) + 0.0722 * canal(argb)
}
