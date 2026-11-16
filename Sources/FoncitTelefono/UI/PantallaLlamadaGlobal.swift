import SwiftUI

/// Muestra la pantalla de llamada de Foncit encima de cualquier pantalla de la app (no solo en la del teléfono).
/// Hace falta cuando la app marca con FoncitTelefono.llamar(numero) desde otra pantalla (una conversación, un contacto…).
private struct PantallaLlamadaGlobal: ViewModifier {
    @ObservedObject private var motor = MotorLlamadas.compartido
    @State private var abierta = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                /** Desde ahora la muestra esta raíz; FoncitTelefonoPantalla ya no abre la suya (dos a la vez no se pueden presentar) */
                MotorLlamadas.compartido.pantallaGlobal = true
                abierta = motor.estado.llamada != nil
            }
            .onChange(of: motor.estado.llamada != nil) { hayLlamada in
                abierta = hayLlamada
            }
            .fullScreenCover(isPresented: $abierta) {
                LlamadaVista()
            }
    }
}

public extension View {
    /**
     Ponlo una vez en la vista raíz de tu app para que la pantalla de llamada salga desde cualquier pantalla:
     ```
     ContentView().foncitPantallaLlamada()
     ```
     */
    func foncitPantallaLlamada() -> some View {
        modifier(PantallaLlamadaGlobal())
    }
}
