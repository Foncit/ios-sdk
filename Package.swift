// swift-tools-version:5.9
// Foncit: teléfono móvil para apps iOS. Este Package.swift sirve para compilar el SDK en la Mac (xcodebuild);
// las apps lo instalan con CocoaPods (FoncitTelefono.podspec, publicado en stg-ios.foncit.com con ./publicar.sh).
import PackageDescription

let package = Package(
    name: "FoncitTelefono",
    defaultLocalization: "es",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "FoncitTelefono", targets: ["FoncitTelefono"])
    ],
    dependencies: [
        /** Motor de llamadas (Linphone) */
        .package(url: "https://github.com/BelledonneCommunications/linphone-sdk-swift-ios.git", .upToNextMajor(from: "5.4.0"))
    ],
    targets: [
        .target(
            name: "FoncitTelefono",
            dependencies: [.product(name: "linphonesw", package: "linphone-sdk-swift-ios")],
            path: "Sources/FoncitTelefono",
            resources: [.process("Resources")]
        )
    ]
)
