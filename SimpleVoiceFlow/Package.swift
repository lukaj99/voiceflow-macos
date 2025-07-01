
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleVoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SimpleVoiceFlow",
            targets: ["SimpleVoiceFlow"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SimpleVoiceFlow",
            path: "."
        )
    ]
)
