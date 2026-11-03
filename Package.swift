// swift-tools-version:5.9
// Foncit: teléfono móvil para apps iOS v2 (Linphone 100% integrado sin descargas externas).
import PackageDescription

let package = Package(
    name: "FoncitTelefono",
    defaultLocalization: "es",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "FoncitTelefono", targets: ["FoncitTelefono"])
    ],
    dependencies: [],
    targets: [
        // Frameworks binarios locales de Linphone (embebidos en Frameworks/)
        .binaryTarget(name: "bctoolbox-ios", path: "Frameworks/bctoolbox-ios.xcframework"),
        .binaryTarget(name: "bctoolbox-tester", path: "Frameworks/bctoolbox-tester.xcframework"),
        .binaryTarget(name: "bctoolbox", path: "Frameworks/bctoolbox.xcframework"),
        .binaryTarget(name: "belcard", path: "Frameworks/belcard.xcframework"),
        .binaryTarget(name: "belle-sip", path: "Frameworks/belle-sip.xcframework"),
        .binaryTarget(name: "belr", path: "Frameworks/belr.xcframework"),
        .binaryTarget(name: "lime", path: "Frameworks/lime.xcframework"),
        .binaryTarget(name: "linphone", path: "Frameworks/linphone.xcframework"),
        .binaryTarget(name: "linphonetester", path: "Frameworks/linphonetester.xcframework"),
        .binaryTarget(name: "mbedcrypto", path: "Frameworks/mbedcrypto.xcframework"),
        .binaryTarget(name: "mbedtls", path: "Frameworks/mbedtls.xcframework"),
        .binaryTarget(name: "mbedx509", path: "Frameworks/mbedx509.xcframework"),
        .binaryTarget(name: "mediastreamer2", path: "Frameworks/mediastreamer2.xcframework"),
        .binaryTarget(name: "msamr", path: "Frameworks/msamr.xcframework"),
        .binaryTarget(name: "mscodec2", path: "Frameworks/mscodec2.xcframework"),
        .binaryTarget(name: "msopenh264", path: "Frameworks/msopenh264.xcframework"),
        .binaryTarget(name: "ortp", path: "Frameworks/ortp.xcframework"),

        // Wrapper de Swift para Linphone (código local)
        .target(
            name: "linphonesw",
            dependencies: [
                "bctoolbox-ios", "bctoolbox-tester", "bctoolbox", "belcard", "belle-sip",
                "belr", "lime", "linphone", "linphonetester", "mbedcrypto", "mbedtls",
                "mbedx509", "mediastreamer2", "msamr", "mscodec2", "msopenh264", "ortp"
            ],
            path: "Sources/linphonesw"
        ),

        // SDK de Foncit Teléfono
        .target(
            name: "FoncitTelefono",
            dependencies: ["linphonesw"],
            path: "Sources/FoncitTelefono",
            resources: [.process("Resources")]
        )
    ]
)
