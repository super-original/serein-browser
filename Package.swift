// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Serein",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Serein", targets: ["Serein"])],
    targets: [
        .target(name: "SereinCore"),
        .executableTarget(name: "Serein", dependencies: ["SereinCore"]),
        .testTarget(name: "SereinCoreTests", dependencies: ["SereinCore"])
    ]
)
