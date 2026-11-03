import SwiftUI

/// Pantalla de llamada (entrante o en curso) dentro de la app. Con el celular bloqueado o la app cerrada la muestra CallKit.
struct LlamadaVista: View {
    @ObservedObject private var motor = MotorLlamadas.compartido
    @Environment(\.dismiss) private var cerrar
    @State private var tecladoAbierto = false

    private let fondo = Color(argb: 0xFF0B1326)
    private let boton = Color(argb: 0xFF182542)
    private let gris = Color(argb: 0xFF94A3B8)

    var body: some View {
        let llamada = motor.estado.llamada
        VStack(spacing: 0) {
            Spacer().frame(height: 64)
            ZStack {
                Circle().fill(boton).frame(width: 96, height: 96)
                Text(inicial(llamada)).font(.system(size: 38)).foregroundColor(.white)
            }
            Spacer().frame(height: 20)
            Text(titulo(llamada)).font(.system(size: 26, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            if let llamada = llamada, !llamada.nombre.isEmpty {
                Text(llamada.numero).font(.system(size: 16)).foregroundColor(gris)
            }
            Spacer().frame(height: 8)
            TimelineView(.periodic(from: .now, by: 1)) { contexto in
                Text(textoEstado(llamada, ahora: contexto.date)).font(.system(size: 16)).foregroundColor(gris)
            }
            Spacer()

            if llamada?.estado == .entrante {
                HStack {
                    Spacer()
                    BotonRedondo(icono: "phone.down.fill", texto: Textos.t("foncit_rechazar"), color: rojoFoncit) { LlamadasSistema.compartido.colgar() }
                    Spacer()
                    BotonRedondo(icono: "phone.fill", texto: Textos.t("foncit_contestar"), color: verdeFoncit) { LlamadasSistema.compartido.contestar() }
                    Spacer()
                }
            } else {
                if tecladoAbierto {
                    TecladoTonos(fondo: boton)
                    Spacer().frame(height: 16)
                }
                HStack {
                    BotonOpcion(icono: "mic.slash.fill", texto: Textos.t("foncit_silenciar"), activo: llamada?.silenciada == true) { LlamadasSistema.compartido.silenciar() }
                    BotonOpcion(icono: "circle.grid.3x3.fill", texto: Textos.t("foncit_teclado"), activo: tecladoAbierto) { tecladoAbierto.toggle() }
                    BotonOpcion(icono: "speaker.wave.2.fill", texto: Textos.t("foncit_altavoz"), activo: llamada?.altavoz == true) { motor.altavoz() }
                    BotonOpcion(icono: "pause.fill", texto: Textos.t("foncit_espera"), activo: llamada?.estado == .enEspera) { LlamadasSistema.compartido.espera() }
                }
                Spacer().frame(height: 28)
                BotonRedondo(icono: "phone.down.fill", texto: Textos.t("foncit_colgar"), color: rojoFoncit) { LlamadasSistema.compartido.colgar() }
            }
            Spacer().frame(height: 32)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fondo.ignoresSafeArea())
        .onChange(of: llamada == nil) { sinLlamada in
            if sinLlamada {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    if motor.estado.llamada == nil { cerrar() }
                }
            }
        }
    }

    private func titulo(_ llamada: LlamadaActual?) -> String {
        guard let llamada = llamada else { return "" }
        return llamada.nombre.isEmpty ? llamada.numero : llamada.nombre
    }

    private func inicial(_ llamada: LlamadaActual?) -> String {
        let texto = titulo(llamada)
        return texto.isEmpty ? "?" : String(texto.prefix(1)).uppercased()
    }

    private func textoEstado(_ llamada: LlamadaActual?, ahora: Date) -> String {
        switch llamada?.estado {
        case .entrante: return Textos.t("foncit_entrante")
        case .marcando: return Textos.t("foncit_marcando")
        case .sonando: return Textos.t("foncit_sonando")
        case .enEspera: return Textos.t("foncit_en_espera")
        case .enCurso:
            let segundos = max(0, Int(ahora.timeIntervalSince(llamada?.inicio ?? ahora)))
            return String(format: "%02d:%02d", segundos / 60, segundos % 60)
        default: return Textos.t("foncit_terminada")
        }
    }
}

private struct TecladoTonos: View {
    let fondo: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(["123", "456", "789", "*0#"], id: \.self) { fila in
                HStack {
                    ForEach(Array(fila), id: \.self) { digito in
                        Spacer()
                        Button { MotorLlamadas.compartido.tono(digito) } label: {
                            Text(String(digito)).font(.system(size: 22)).foregroundColor(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(fondo))
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct BotonRedondo: View {
    let icono: String
    let texto: String
    let color: Color
    let alPresionar: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: alPresionar) {
                Image(systemName: icono).font(.system(size: 28)).foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(color))
            }
            Text(texto).font(.system(size: 13)).foregroundColor(Color(argb: 0xFF94A3B8))
        }
    }
}

private struct BotonOpcion: View {
    let icono: String
    let texto: String
    let activo: Bool
    let alPresionar: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: alPresionar) {
                Image(systemName: icono).font(.system(size: 20))
                    .foregroundColor(activo ? Color(argb: 0xFF0B1326) : .white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(activo ? Color.white : Color(argb: 0xFF182542)))
            }
            Text(texto).font(.system(size: 12)).foregroundColor(Color(argb: 0xFF94A3B8))
        }
        .frame(maxWidth: .infinity)
    }
}
