// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VoiceFlowCore",
            targets: ["VoiceFlowCore"]
        ),
        .library(
            name: "VoiceFlowUI",
            targets: ["VoiceFlowUI"]
        )
    ],
    dependencies: [
        // HotKey for global keyboard shortcuts
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        // KeychainAccess for secure storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "3.2.1"),
        // AsyncAlgorithms for stream processing
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        // Core functionality target
        .target(
            name: "VoiceFlowCore",
            dependencies: [
                "KeychainAccess",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "VoiceFlow/Core"
        ),
        
        // UI components target
        .target(
            name: "VoiceFlowUI",
            dependencies: [
                "VoiceFlowCore",
                "HotKey"
            ],
            path: "VoiceFlow/Features"
        ),
        
        // Test targets
        .testTarget(
            name: "VoiceFlowCoreTests",
            dependencies: ["VoiceFlowCore"],
            path: "VoiceFlowTests/Unit"
        ),
        
        .testTarget(
            name: "VoiceFlowIntegrationTests",
            dependencies: ["VoiceFlowCore", "VoiceFlowUI"],
            path: "VoiceFlowTests/Integration"
        ),
        
        .testTarget(
            name: "VoiceFlowPerformanceTests",
            dependencies: ["VoiceFlowCore"],
            path: "VoiceFlowTests/Performance"
        )
    ]
)