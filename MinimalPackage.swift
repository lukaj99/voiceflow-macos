// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoiceFlow",
            targets: ["VoiceFlow"]
        )
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlow",
            path: "VoiceFlow",
            sources: [
                "main.swift",
                "SimpleApp.swift"
            ]
        )
    ]
)