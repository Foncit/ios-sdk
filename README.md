# Foncit Teléfono — SDK iOS

Teléfono completo (teclado, recientes, llamada entrante y en curso) para cualquier app iOS 15+ (SwiftUI o UIKit).
Usa Linphone con **SIP por TLS (5061)** y **voz cifrada SRTP**, la pantalla de llamadas del sistema (**CallKit**) y avisos
**VoIP (PushKit)** para que suene con la app cerrada. El usuario nunca inicia sesión: la app solo le pasa al SDK el
**identificador de su usuario** (ej. `AgCuentaUsuario`).

## Cómo funciona

```
Panel de Foncit en tu web ──UsuariosExternos──▶ Foncit guarda tus usuarios; ahí les asignas extensiones ("Asignada a")
App (SDK) ──IdExterno + bundle──▶ TelefonoMovilWS: iniciarUsuario ──▶ token permanente
   └──Bearer token──▶ TelefonoMovilWS: mostrarTelefono / registrarDispositivo / mostrarLlamadas
Llamada entrante ──▶ Foncit manda aviso VoIP (Apple) ──▶ el SDK la muestra en CallKit y conecta la línea
```

En **Foncit > Complementos > Plataformas** agrega la app como **iOS** con su **bundle** y tu **Team ID**, y en
"Llamadas con la app cerrada" sube la **llave .p8** de Apple (Apple Push Notifications service) con su Key ID.

## 1. Agregar la librería (CocoaPods)

`Podfile`:

```ruby
platform :ios, '15.0'
source 'https://gitlab.linphone.org/BC/public/podspec.git'   # motor de llamadas
source 'https://cdn.cocoapods.org/'

target 'TuApp' do
  use_frameworks!
  pod 'FoncitTelefono', :podspec => 'https://stg-ios.foncit.com/FoncitTelefono/1.0.0/FoncitTelefono.podspec'
end
```

```
pod install
```

## 2. Ajustes del proyecto (Xcode)

- **Signing & Capabilities**: `Push Notifications` y `Background Modes` con **Voice over IP** y **Audio, AirPlay, and Picture in Picture**.
- **Info.plist**: `NSMicrophoneUsageDescription` (ej. "Para hacer y recibir llamadas").

## 3. Activar avisos y configurar

Al arrancar la app, **siempre** (iOS abre la app cerrada por un aviso de llamada y lo entrega aquí):

```swift
@main
struct MiApp: App {
    init() { FoncitTelefono.activarAvisos() }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

Cuando ya sabes quién es el usuario (y cada vez que cambie):

```swift
FoncitTelefono.configurar(usuario: agCuentaUsuario,
                          ajustes: AjustesFoncit(ambiente: .pruebas, colorPrincipal: 0xFFE9791E))
```

`AjustesFoncit`: `ambiente` (.produccion / .pruebas), `colorPrincipal`, `oscuro` (nil = el del sistema),
`coloresClaro` y `coloresOscuro` (`ColoresFoncit`: principal, fondo, superficie, superficieVariante, texto, textoSecundario).
Para cambiar tema o colores al momento: `FoncitTelefono.cambiarTema(ajustes)`.

## 4. Mostrar el teléfono (una línea)

```swift
FoncitTelefonoPantalla()                // SwiftUI
FoncitTelefonoControlador()             // UIKit (UIViewController)
```

## 5. Cerrar sesión en tu app

```swift
FoncitTelefono.cerrarSesion()
```

## Revisar

En la consola de Xcode filtra por `FoncitTelefono`: `Token de avisos recibido`, `registrarDispositivo: true ...` y
`Aviso de llamada recibido`. Las compilaciones de Debug se registran como sandbox de Apple (`Produccion = 0`) y las de
Release / TestFlight / App Store como producción.
