// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidTone",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LidTone", targets: ["LidTone"])],
    targets: [
        .target(name: "LidToneCore"),
        .target(name: "PowerBridge", publicHeadersPath: "include"),
        .executableTarget(name: "LidTone", dependencies: ["LidToneCore", "PowerBridge"],
                          resources: [.copy("Resources/Sounds")]),
        .testTarget(name: "LidToneCoreTests", dependencies: ["LidToneCore"])
    ]
)
