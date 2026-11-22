// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "G13forever",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "G13Kit", targets: ["G13Kit"]),
        .executable(name: "g13ctl", targets: ["g13ctl"]),
        .executable(name: "G13App", targets: ["G13App"]),
    ],
    targets: [
        // Gerätekern: LCD, Bilder, USB/HID-Zugriff, Profile und Tastenbelegung.
        .target(name: "G13Kit"),
        // Kommandozeilen-Werkzeug für den Display-Prototyp.
        .executableTarget(name: "g13ctl", dependencies: ["G13Kit"]),
        // Menüleisten-App mit Profilen. Als .app bündeln: scripts/build-app.sh
        .executableTarget(name: "G13App", dependencies: ["G13Kit"]),
        .testTarget(name: "G13KitTests", dependencies: ["G13Kit"]),
    ]
)
