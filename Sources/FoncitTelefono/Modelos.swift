import Foundation

/// Ambiente de Foncit al que se conecta el teléfono (las rutas están en Internal/Rutas.swift)
public enum Ambiente: String {
    case produccion = "PRODUCCION"
    case pruebas = "PRUEBAS"
}

/// Colores de la app para un modo (claro u oscuro), en ARGB (ej. 0xFF0B1326). Los que no se manden quedan los de Foncit.
/// - principal: botones y acentos
/// - fondo: fondo de la pantalla
/// - superficie: tarjetas y barras
/// - superficieVariante: teclas del teclado y chips
/// - texto: texto principal
/// - textoSecundario: textos de ayuda
public struct ColoresFoncit: Equatable {
    public var principal: UInt32?
    public var fondo: UInt32?
    public var superficie: UInt32?
    public var superficieVariante: UInt32?
    public var texto: UInt32?
    public var textoSecundario: UInt32?

    public init(principal: UInt32? = nil, fondo: UInt32? = nil, superficie: UInt32? = nil,
                superficieVariante: UInt32? = nil, texto: UInt32? = nil, textoSecundario: UInt32? = nil) {
        self.principal = principal
        self.fondo = fondo
        self.superficie = superficie
        self.superficieVariante = superficieVariante
        self.texto = texto
        self.textoSecundario = textoSecundario
    }
}

/// Ajustes del teléfono. Todos son opcionales.
/// - ambiente: produccion (foncit.com) o pruebas (stg.foncit.com)
/// - colorPrincipal: color de los botones (ARGB) si los colores del modo no traen principal; por defecto el naranja de Foncit
/// - oscuro: tema oscuro; nil = el del sistema
/// - coloresClaro / coloresOscuro: colores de la app en cada modo (los que falten, los de Foncit)
public struct AjustesFoncit: Equatable {
    public var ambiente: Ambiente
    public var colorPrincipal: UInt32
    public var oscuro: Bool?
    public var coloresClaro: ColoresFoncit
    public var coloresOscuro: ColoresFoncit

    public init(ambiente: Ambiente = .produccion, colorPrincipal: UInt32 = 0xFFE9791E, oscuro: Bool? = nil,
                coloresClaro: ColoresFoncit = ColoresFoncit(), coloresOscuro: ColoresFoncit = ColoresFoncit()) {
        self.ambiente = ambiente
        self.colorPrincipal = colorPrincipal
        self.oscuro = oscuro
        self.coloresClaro = coloresClaro
        self.coloresOscuro = coloresOscuro
    }
}

public enum EstadoRegistro { case desconectado, conectando, conectado, error }

public enum EstadoLlamada { case entrante, marcando, sonando, enCurso, enEspera, terminada }

/// Llamada que está sonando o en curso
public struct LlamadaActual: Equatable {
    public var numero: String
    public var nombre: String
    public var entrante: Bool
    public var estado: EstadoLlamada
    public var inicio: Date?
    public var silenciada: Bool = false
    public var altavoz: Bool = false
}

/// Una extensión móvil del usuario (todas reciben llamadas; se marca desde la seleccionada)
public struct ExtensionTelefono: Equatable, Identifiable {
    public var id: String { usuario }
    public var usuario: String
    public var extensionNumero: String
    public var nombre: String
    public var registro: EstadoRegistro = .conectando
}

/// Estado del teléfono que pinta la interfaz.
/// registro, extensionNumero y nombre son los de la extensión seleccionada (con la que se marca).
public struct EstadoTelefono: Equatable {
    public var registro: EstadoRegistro = .desconectado
    public var extensionNumero: String = ""
    public var nombre: String = ""
    public var extensiones: [ExtensionTelefono] = []
    public var seleccionada: String = ""
    public var llamada: LlamadaActual?
    public var mensaje: String?
    /// Foncit respondió que al usuario aún no le asignan extensiones (desde el panel de su plataforma)
    public var sinExtensiones: Bool = false
}

/// Una llamada del historial de Foncit
public struct LlamadaReciente: Identifiable {
    public let id = UUID()
    public var numero: String
    public var nombre: String
    public var direccion: String
    public var estatus: String
    public var duracion: Int
    public var fecha: String
}
