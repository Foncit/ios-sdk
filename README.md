# Foncit Teléfono — SDK para iOS

SDK completo y listo para producción que integra un teléfono VoIP empresarial (marcador telefónico, historial de recientes, control de llamadas entrantes y salientes con **CallKit**) en cualquier app iOS (SwiftUI o UIKit).

Usa el motor de llamadas Linphone con **SIP seguro por TLS (puerto 5061)**, **voz cifrada SRTP** y notificaciones push **VoIP (PushKit)** de alta prioridad para recibir llamadas incluso con la app cerrada o el dispositivo bloqueado.

> **Motor Linphone Integrado**: Linphone y sus dependencias ya vienen precompilados y empaquetados dentro del SDK. No requiere descargas externas, repositorios adicionales de Gitlab ni configuraciones de compiladores C/C++.

---

## 📋 Requisitos del Proyecto

* **iOS 15.0** o superior
* **Xcode 15.0** o superior
* **Swift 5.9** o superior
* Cuenta y plataforma configuradas en [Foncit](https://foncit.com):
  * **Bundle Identifier** y **Team ID** registrados en *Foncit > Complementos > Plataformas*.
  * Llave APNs **`.p8`** (con Key ID) subida en la sección de llamadas con app cerrada.

---

## 🚀 Paso 1: Instalación del SDK

Puedes integrar la librería en tu app mediante **Swift Package Manager** (recomendado por Apple) o mediante **CocoaPods**.

### Opción A: Swift Package Manager (Recomendado)

1. Abre tu proyecto en **Xcode**.
2. En la barra de menús, selecciona: **File** > **Add Package Dependencies...**
3. En la barra de búsqueda superior derecha, pega la URL del repositorio:
   ```text
   https://github.com/Foncit/ios-sdk.git
   ```
4. En **Dependency Rule**, selecciona:
   * **Exact Version** o **Up to Next Minor**: `1.0.1` (o la versión que desees).
5. Haz clic en **Add Package** y asegúrate de marcar la casilla **FoncitTelefono** en tu Target principal.
6. ¡Listo! Xcode vinculará el SDK automáticamente.

---

### Opción B: CocoaPods

Si tu proyecto utiliza CocoaPods, agrega la siguiente línea a tu archivo `Podfile`:

```ruby
platform :ios, '15.0'

target 'TuApp' do
  use_frameworks!
  
  # SDK Foncit con Linphone integrado
  pod 'FoncitTelefono', :git => 'https://github.com/Foncit/ios-sdk.git', :tag => '1.0.1'
end
```

Luego ejecuta en la terminal de tu proyecto:
```bash
pod install --repo-update
```

---

## ⚙️ Paso 2: Capacidades y Permisos en Xcode

Para que iOS permita recibir llamadas con la pantalla bloqueada y usar el micrófono, es obligatorio habilitar estas opciones en el proyecto de tu app:

### 1. Activar Capacidades (Capabilities)
1. En Xcode, selecciona tu proyecto en el navegador de la izquierda y entra a tu **Target**.
2. Ve a la pestaña **Signing & Capabilities**.
3. Haz clic en **`+ Capability`** y agrega:
   * **Push Notifications**
4. Vuelve a hacer clic en **`+ Capability`** y agrega:
   * **Background Modes**
   * Dentro de Background Modes, marca las casillas:
     * ☑ **Voice over IP** (para recibir llamadas con app cerrada vía PushKit).
     * ☑ **Audio, AirPlay, and Picture in Picture** (para mantener la llamada activa en segundo plano).

### 2. Permiso de Micrófono en `Info.plist`
Abre tu archivo `Info.plist` (o la pestaña *Info* del Target) y agrega la siguiente clave:

| Clave (Key) | Tipo | Valor sugerido |
| :--- | :--- | :--- |
| `Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`) | String | *"Necesitamos acceso al micrófono para que puedas realizar y responder llamadas telefónicas."* |

---

## 💻 Paso 3: Inicialización en el arranque de la app

Apple exige que el registro de avisos VoIP (`PushKit`) se active **inmediatamente al arrancar la app**, para poder procesar una llamada entrante cuando iOS despierta la app en segundo plano.

### Si tu app es SwiftUI (`@main`):

```swift
import SwiftUI
import FoncitTelefono

@main
struct MiApp: App {
    
    init() {
        // Obligatorio: activar escucha de llamadas entrantes
        FoncitTelefono.activarAvisos()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Si tu app usa UIKit (`AppDelegate`):

```swift
import UIKit
import FoncitTelefono

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Obligatorio: activar escucha de llamadas entrantes
        FoncitTelefono.activarAvisos()
        return true
    }
}
```

---

## 🔑 Paso 4: Identificar al Usuario (Login)

Cuando el usuario inicia sesión en tu aplicación (o cuando ya conoces su identificador externo en Foncit, ej. `AgCuentaUsuario`), configúralo en el SDK:

```swift
// Configuración básica (Ambiente Producción por defecto):
FoncitTelefono.configurar(usuario: "ID_DE_TU_USUARIO")

// O con ajustes de ambiente y color corporativo:
FoncitTelefono.configurar(
    usuario: "ID_DE_TU_USUARIO",
    ajustes: AjustesFoncit(
        ambiente: .pruebas,          // .produccion o .pruebas
        colorPrincipal: 0xFFE9791E   // Color hexadecimal principal
    )
)
```

> **Nota**: El usuario no necesita contraseña SIP; el SDK negocia automáticamente las credenciales seguras con el servidor de Foncit a través de su identificador de cuenta.

---

## 📱 Paso 5: Mostrar la Pantalla del Teléfono

El SDK incluye una pantalla completa y estilizada con teclado numérico, selector de extensiones, historial de llamadas y llamada en curso.

### En SwiftUI:

Puedes colocarla directamente en una vista, dentro de un `TabView`, o presentarla en una hoja modal (`sheet`):

```swift
import SwiftUI
import FoncitTelefono

struct PantallaPrincipalView: View {
    @State private var mostrarTelefono = false

    var body: some View {
        Button(action: { mostrarTelefono = true }) {
            Label("Abrir Teléfono", systemImage: "phone.fill")
        }
        .sheet(isPresented: $mostrarTelefono) {
            // Vista completa del teléfono:
            FoncitTelefonoPantalla()
        }
    }
}
```

### En UIKit:

Puedes presentarla como un `UIViewController` estándar:

```swift
import UIKit
import FoncitTelefono

class MiControlador: UIViewController {

    @IBAction func abrirTelefonoPresionado(_ sender: Any) {
        let telefonoVC = FoncitTelefonoControlador()
        telefonoVC.modalPresentationStyle = .fullScreen
        self.present(telefonoVC, animated: true)
    }
}
```

---

## 🎨 Paso 6: Personalización Visual y Temas

Puedes adaptar el aspecto del teléfono a la identidad visual de tu aplicación:

```swift
let temaPersonalizado = AjustesFoncit(
    ambiente: .produccion,
    colorPrincipal: 0xFF007AFF,  // Color de botones de llamada y acentos
    oscuro: nil,                  // nil = sigue el modo del sistema; true = siempre oscuro; false = siempre claro
    coloresClaro: ColoresFoncit(
        principal: 0xFF007AFF,
        fondo: 0xFFFFFFFF,
        superficie: 0xFFF2F2F7,
        superficieVariante: 0xFFE5E5EA,
        texto: 0xFF000000,
        textoSecundario: 0xFF8E8E93
    ),
    coloresOscuro: ColoresFoncit(
        principal: 0xFF0A84FF,
        fondo: 0xFF000000,
        superficie: 0xFF1C1C1E,
        superficieVariante: 0xFF2C2C2E,
        texto: 0xFFFFFFFF,
        textoSecundario: 0xFF8E8E93
    )
)

// Cambiar tema dinámicamente:
FoncitTelefono.cambiarTema(temaPersonalizado)
```

---

## 📞 Paso 7: Operaciones Programáticas (Opcional)

Si prefieres disparar llamadas o gestionar el teléfono sin usar la vista completa:

```swift
// Realizar una llamada directa a un número o extensión:
FoncitTelefono.llamar("+525512345678")

// Cambiar de extensión asignada:
FoncitTelefono.seleccionarExtension("101")

// Conectar manualmente el motor SIP:
FoncitTelefono.iniciar()

// Conocer el estado actual del teléfono:
let estado = FoncitTelefono.estado
print("Conexión: \(estado.registro) - Llamada: \(estado.llamada?.estado ?? .terminada)")
```

---

## 🚪 Paso 8: Cierre de Sesión (Logout)

Cuando el usuario cierre sesión en tu aplicación, invoca el método de desconexión. Esto dará de baja el token VoIP en la nube de Foncit para que el dispositivo deje de recibir llamadas de ese usuario:

```swift
FoncitTelefono.cerrarSesion()
```

---

## 🔍 Depuración y Registro de Eventos (Logs)

Para comprobar el correcto funcionamiento en el simulador o celular físico:

1. Conecta el dispositivo y abre la consola de **Xcode** (o la app *Console.app* en macOS).
2. En la barra de filtro escribe: `FoncitTelefono`.
3. Verás los eventos principales del ciclo de vida:
   * `Token de avisos recibido (ios, usuario guardado: true)`: El token VoIP de Apple se generó correctamente.
   * `registrarDispositivo: true`: El dispositivo quedó registrado en la central telefónica de Foncit.
   * `Aviso de llamada recibido`: Apple entregó la notificación VoIP y CallKit activó la pantalla de llamada.

> **Diferencia Sandbox / Producción**:
> * Compilaciones en modo **Debug**: Se registran automáticamente en el servidor APNs Sandbox de Apple (`Produccion = 0`).
> * Compilaciones de **Release / TestFlight / App Store**: Se registran automáticamente en el servidor APNs de Producción de Apple (`Produccion = 1`).

---

## 🛡️ Soporte y Licencia

Desarrollado y mantenido por **Foncit**. Todos los derechos reservados.  
Para soporte técnico o dudas sobre la integración: [foncit.com](https://foncit.com).
