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
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlow",
            dependencies: [
                "HotKey", 
                "KeychainAccess",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                "Starscream"
            ],
            path: "VoiceFlow",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("GlobalConcurrency"),
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
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "VoiceFlowTests",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("GlobalConcurrency"),
                .define("SWIFT_CONCURRENCY_STRICT")
            ]
        )
    ]
)