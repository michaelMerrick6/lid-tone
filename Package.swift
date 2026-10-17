// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "LidTone",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LidTone", targets: ["LidTone"])],
    targets: [
        .target(name: "LidToneCore"),
        .target(name: "HingeAudio", publicHeadersPath: "include"),
        .executableTarget(name: "LidTone", dependencies: ["LidToneCore", "HingeAudio"],
                          resources: [.copy("Resources/Audio")]),
        .testTarget(name: "LidToneCoreTests", dependencies: ["LidToneCore", "HingeAudio"])
    ]
)
