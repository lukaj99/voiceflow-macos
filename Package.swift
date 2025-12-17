// swift-tools-version: 6.2
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
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.0"),
        .package(path: "ThirdParty/Starscream")
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlow",
            dependencies: [
                "HotKey",
                "KeychainAccess",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                "Starscream"
            ],
            path: "VoiceFlow",
            exclude: [
                "Documentation/LLM-Integration-Guide.md",
                "Resources/Entitlements/VoiceFlow.entitlements",
                "Resources/Assets.xcassets",
                "App/Info.plist"
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .define("SWIFT_CONCURRENCY_STRICT")
            ],
            linkerSettings: [
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "VoiceFlowTests",
            dependencies: [
                "VoiceFlow",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            path: "VoiceFlowTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .define("SWIFT_CONCURRENCY_STRICT")
            ]
        )
    ]
)
