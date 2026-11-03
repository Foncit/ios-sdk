# Foncit Teléfono — SDK iOS (Versión 2)

Teléfono completo (teclado, recientes, llamada entrante y en curso) para cualquier app iOS 15+ (SwiftUI o UIKit).
Usa Linphone con **SIP por TLS (5061)** y **voz cifrada SRTP**, la pantalla de llamadas del sistema (**CallKit**) y avisos **VoIP (PushKit)** para que suene con la app cerrada.

> **Novedad en V2**: Linphone viene **100% integrado dentro del SDK**.  
> El cliente final ya **no** tiene que agregar repositorios externos de Gitlab ni descargar Linphone por separado en su app. Al importar este repo o pod, Linphone ya viene incluido y listo para usar.

---

## Cómo funciona

```
Panel de Foncit en tu web ──UsuariosExternos──▶ Foncit guarda tus usuarios; ahí les asignas extensiones ("Asignada a")
App (SDK) ──IdExterno + bundle──▶ TelefonoMovilWS: iniciarUsuario ──▶ token permanente
   └──Bearer token──▶ TelefonoMovilWS: mostrarTelefono / registrarDispositivo / mostrarLlamadas
Llamada entrante ──▶ Foncit manda aviso VoIP (Apple) ──▶ el SDK la muestra en CallKit y conecta la línea
```

En **Foncit > Complementos > Plataformas** agrega la app como **iOS** con su **bundle** y tu **Team ID**, y en "Llamadas con la app cerrada" sube la **llave .p8** de Apple (Apple Push Notifications service) con su Key ID.

---

## 1. Agregar la librería al proyecto del cliente

Puedes integrar el SDK de dos formas:

### Opción A: Swift Package Manager (Recomendado - Git directo)

1. En Xcode: **File > Add Package Dependencies...**
2. Ingresa la URL de este repositorio Git: `https://github.com/tu-organizacion/Foncit_sdk.git` (o agrega la carpeta local).
3. Selecciona la versión `2.0.0` y marca la librería **FoncitTelefono**.
4. ¡Listo! Linphone y el SDK se vinculan automáticamente sin descargas manuales.

---

### Opción B: CocoaPods

En el `Podfile` de la app cliente (ya **no** requiere la fuente de Gitlab de Linphone):

```ruby
platform :ios, '15.0'

target 'TuApp' do
  use_frameworks!
  pod 'FoncitTelefono', :podspec => 'https://stg-ios.foncit.com/FoncitTelefono/2.0.0/FoncitTelefono.podspec'
end
```

```bash
pod install
```

---

## 2. Ajustes obligatorios de Apple (Xcode)

Apple exige que la app principal declare estos permisos:

- **Signing & Capabilities**:
  - `Push Notifications`
  - `Background Modes` activando:
    - **Voice over IP**
    - **Audio, AirPlay, and Picture in Picture**
- **Info.plist**:
  - `NSMicrophoneUsageDescription` (ej. *"Para hacer y recibir llamadas"*).

---

## 3. Activar avisos y configurar

Al arrancar la app, **siempre** (iOS abre la app cerrada por un aviso de llamada y lo entrega aquí):

```swift
import SwiftUI
import FoncitTelefono

@main
struct MiApp: App {
    init() { FoncitTelefono.activarAvisos() }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

Cuando ya sabes quién es el usuario (y cada vez que cambie):

```swift
FoncitTelefono.configurar(
    usuario: agCuentaUsuario,
    ajustes: AjustesFoncit(ambiente: .pruebas, colorPrincipal: 0xFFE9791E)
)
```

`AjustesFoncit`: `ambiente` (.produccion / .pruebas), `colorPrincipal`, `oscuro` (nil = el del sistema), `coloresClaro` y `coloresOscuro` (`ColoresFoncit`: principal, fondo, superficie, superficieVariante, texto, textoSecundario).  
Para cambiar tema o colores al momento: `FoncitTelefono.cambiarTema(ajustes)`.

---

## 4. Mostrar el teléfono (una línea)

```swift
FoncitTelefonoPantalla()                // SwiftUI
FoncitTelefonoControlador()             // UIKit (UIViewController)
```

---

## 5. Cerrar sesión en tu app

```swift
FoncitTelefono.cerrarSesion()
```

---

## Revisar

En la consola de Xcode filtra por `FoncitTelefono`:
- `Token de avisos recibido`
- `registrarDispositivo: true ...`
- `Aviso de llamada recibido`

Las compilaciones de Debug se registran como sandbox de Apple (`Produccion = 0`) y las de Release / TestFlight / App Store como producción.
