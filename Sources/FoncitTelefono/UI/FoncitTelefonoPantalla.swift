import SwiftUI
import AVFoundation
import UIKit

/**
 Pantalla completa del teléfono (teclado y recientes). Con esta sola línea la app tiene teléfono:
 ```
 FoncitTelefonoPantalla()
 ```
 Pide el permiso del micrófono, conecta las extensiones y muestra la pantalla de llamada cuando hace falta.
 */
public struct FoncitTelefonoPantalla: View {
    @ObservedObject private var motor = MotorLlamadas.compartido
    @Environment(\.colorScheme) private var esquema
    @State private var pestana = 0
    @State private var conPermiso = AVAudioSession.sharedInstance().recordPermission != .denied
    @State private var llamadaAbierta = false

    public init() {}

    public var body: some View {
        let tema = TemaFoncit(ajustes: motor.ajustes, esquema: esquema)
        let estado = motor.estado
        let conExtensiones = !estado.extensiones.isEmpty
        VStack(spacing: 0) {
            Picker("", selection: $pestana) {
                Text(Textos.t("foncit_teclado")).tag(0)
                Text(Textos.t("foncit_recientes")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Encabezado(estado: estado, tema: tema)

            if !conPermiso {
                Aviso(texto: Textos.t("foncit_permiso_microfono"), boton: Textos.t("foncit_permitir"), tema: tema) {
                    if let ajustes = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(ajustes) }
                }
            }

            if estado.llamada != nil {
                Button { llamadaAbierta = true } label: {
                    Text(Textos.t("foncit_volver_llamada"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(verdeFoncit)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            if !conExtensiones && estado.registro == .error {
                Aviso(texto: textoSinTelefono(estado), boton: Textos.t("foncit_reintentar"), tema: tema) { FoncitTelefono.iniciar() }
            }

            if pestana == 0 {
                Teclado(puedeLlamar: conExtensiones, tema: tema)
            } else {
                Recientes(tema: tema)
            }
        }
        .background(tema.fondo.ignoresSafeArea())
        .onAppear {
            AVAudioSession.sharedInstance().requestRecordPermission { permitido in
                DispatchQueue.main.async { conPermiso = permitido }
            }
            FoncitTelefono.iniciar()
        }
        .onChange(of: estado.llamada != nil) { hayLlamada in
            llamadaAbierta = hayLlamada
        }
        .fullScreenCover(isPresented: $llamadaAbierta) {
            LlamadaVista()
        }
    }

    private func textoSinTelefono(_ estado: EstadoTelefono) -> String {
        if estado.sinExtensiones { return Textos.t("foncit_sin_extensiones") }
        if let mensaje = estado.mensaje, !mensaje.isEmpty { return mensaje }
        return Textos.t("foncit_sin_servidor")
    }
}

func colorRegistro(_ registro: EstadoRegistro) -> Color {
    switch registro {
    case .conectado: return verdeFoncit
    case .conectando: return ambarFoncit
    default: return rojoFoncit
    }
}

/// Extensión con la que se marca y su estado; con varias, al tocarla se elige otra ("Llamar desde"). Todas reciben llamadas
private struct Encabezado: View {
    let estado: EstadoTelefono
    let tema: TemaFoncit

    var body: some View {
        let varias = estado.extensiones.count > 1
        let color = colorRegistro(estado.registro)
        let textoRegistro: String = {
            switch estado.registro {
            case .conectado: return Textos.t("foncit_conectado")
            case .conectando: return Textos.t("foncit_conectando")
            default: return Textos.t("foncit_desconectado")
            }
        }()
        HStack(spacing: 8) {
            Menu {
                ForEach(estado.extensiones) { ext in
                    Button {
                        FoncitTelefono.seleccionarExtension(ext.usuario)
                    } label: {
                        Label(
                            ext.nombre.isEmpty ? Textos.t("foncit_extension", ext.extensionNumero) : "\(ext.nombre) · \(ext.extensionNumero)",
                            systemImage: ext.usuario == estado.seleccionada ? "checkmark" : (ext.registro == .conectado ? "circle.fill" : "circle")
                        )
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(tema.principal.opacity(0.12)).frame(width: 38, height: 38)
                        Image(systemName: "phone.fill").foregroundColor(tema.principal).font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Text(estado.nombre.isEmpty ? Textos.t("foncit_titulo") : estado.nombre)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(tema.texto)
                                .lineLimit(1)
                            if varias {
                                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(tema.textoSecundario)
                            }
                        }
                        HStack(spacing: 0) {
                            if varias {
                                Text(Textos.t("foncit_llamar_desde") + " • ").font(.system(size: 12)).foregroundColor(tema.textoSecundario)
                            }
                            if !estado.extensionNumero.isEmpty {
                                Text(Textos.t("foncit_extension", estado.extensionNumero))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(tema.textoSecundario)
                            }
                        }
                    }
                }
            }
            .disabled(!varias)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(textoRegistro).font(.system(size: 11, weight: .bold)).foregroundColor(color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())

            if estado.registro == .error || estado.registro == .desconectado {
                Button { FoncitTelefono.iniciar() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .bold))
                        Text(Textos.t("foncit_reintentar")).font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(tema.principal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tema.principal.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(tema.superficieVariante.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Aviso en rojo con un botón (permiso del micrófono o sin extensiones)
private struct Aviso: View {
    let texto: String
    let boton: String
    let tema: TemaFoncit
    let alPresionar: () -> Void

    var body: some View {
        HStack {
            Text(texto).font(.system(size: 13)).foregroundColor(rojoFoncit)
            Spacer(minLength: 8)
            Button(boton, action: alPresionar).font(.system(size: 14, weight: .semibold)).foregroundColor(tema.principal)
        }
        .padding(12)
        .background(rojoFoncit.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private let teclas: [(String, String)] = [
    ("1", ""), ("2", "ABC"), ("3", "DEF"),
    ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
    ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
    ("*", ""), ("0", "+"), ("#", "")
]

private struct Teclado: View {
    let puedeLlamar: Bool
    let tema: TemaFoncit
    @State private var numero = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            Text(numero.isEmpty ? Textos.t("foncit_marcar") : numero)
                .font(.system(size: numero.isEmpty ? 18 : 32, weight: .semibold))
                .foregroundColor(numero.isEmpty ? tema.textoSecundario.opacity(0.6) : tema.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            Spacer(minLength: 8)

            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { fila in
                    HStack {
                        ForEach(0..<3, id: \.self) { columna in
                            let tecla = teclas[fila * 3 + columna]
                            Spacer()
                            Tecla(digito: tecla.0, letras: tecla.1, tema: tema,
                                  alPresionar: { numero += tecla.0 },
                                  alMantener: tecla.0 == "0" ? { numero += "+" } : nil)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            HStack {
                Spacer().frame(width: 56, height: 56)
                Spacer()
                Button {
                    if !numero.isEmpty { FoncitTelefono.llamar(numero) }
                } label: {
                    ZStack {
                        Circle().fill(puedeLlamar ? verdeFoncit : verdeFoncit.opacity(0.35)).frame(width: 68, height: 68)
                        Image(systemName: "phone.fill").font(.system(size: 28)).foregroundColor(.white)
                    }
                }
                .disabled(!puedeLlamar)
                .accessibilityLabel(Textos.t("foncit_llamar"))
                Spacer()
                ZStack {
                    if !numero.isEmpty {
                        Button { numero.removeLast() } label: {
                            Image(systemName: "delete.left").font(.system(size: 22)).foregroundColor(tema.textoSecundario)
                        }
                        .accessibilityLabel(Textos.t("foncit_borrar"))
                    }
                }
                .frame(width: 56, height: 56)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }
}

private struct Tecla: View {
    let digito: String
    let letras: String
    let tema: TemaFoncit
    let alPresionar: () -> Void
    let alMantener: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text(digito).font(.system(size: 26, weight: .semibold)).foregroundColor(tema.texto)
            if !letras.isEmpty {
                Text(letras).font(.system(size: 9, weight: .medium)).kerning(1).foregroundColor(tema.textoSecundario)
            }
        }
        .frame(width: 72, height: 72)
        .background(Circle().fill(tema.superficieVariante.opacity(0.6)))
        .contentShape(Circle())
        .onTapGesture(perform: alPresionar)
        .onLongPressGesture { alMantener?() }
    }
}

private struct Recientes: View {
    let tema: TemaFoncit
    @State private var llamadas: [LlamadaReciente]?

    var body: some View {
        Group {
            if let lista = llamadas {
                if lista.isEmpty {
                    VStack { Spacer(); Text(Textos.t("foncit_sin_recientes")).foregroundColor(tema.textoSecundario); Spacer() }
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(lista) { l in fila(l) }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity)
            }
        }
        .task {
            llamadas = (try? await ApiFoncit.mostrarLlamadas()) ?? []
        }
    }

    private func fila(_ l: LlamadaReciente) -> some View {
        let perdida = l.direccion == "entrante" && l.estatus != "contestada"
        let icono = perdida ? "phone.arrow.down.left" : (l.direccion == "saliente" ? "phone.arrow.up.right" : "phone.arrow.down.left")
        let color = perdida ? rojoFoncit : (l.direccion == "saliente" ? tema.principal : verdeFoncit)
        return Button { FoncitTelefono.llamar(l.numero) } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icono).foregroundColor(color).font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.nombre.isEmpty ? l.numero : l.nombre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(perdida ? rojoFoncit : tema.texto)
                    Text(String(l.fecha.prefix(16))).font(.system(size: 12)).foregroundColor(tema.textoSecundario)
                }
                Spacer()
                Image(systemName: "phone.fill").foregroundColor(verdeFoncit).font(.system(size: 18))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Para apps con UIKit: el teléfono como controlador
public func FoncitTelefonoControlador() -> UIViewController {
    UIHostingController(rootView: FoncitTelefonoPantalla())
}
