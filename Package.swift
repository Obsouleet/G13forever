// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "G13forever",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "G13Kit", targets: ["G13Kit"]),
        .executable(name: "g13ctl", targets: ["g13ctl"]),
    ],
    targets: [
        // Gerätekern: LCD-Framebuffer, Bildkonvertierung, USB/HID-Zugriff.
        .target(name: "G13Kit"),
        // Kommandozeilen-Werkzeug für den Display-Prototyp.
        .executableTarget(name: "g13ctl", dependencies: ["G13Kit"]),
        .testTarget(name: "G13KitTests", dependencies: ["G13Kit"]),
    ]
)
