// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
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
            dependencies: [
                "HotKey", 
                "KeychainAccess",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "VoiceFlow",
            sources: [
                "main.swift",
                "AdvancedApp.swift",
                "Core/TranscriptionEngine/TranscriptionModels.swift",
                "Core/TranscriptionEngine/AudioEngineManager.swift",
                "Core/TranscriptionEngine/RealSpeechRecognitionEngine.swift",
                "Core/TranscriptionEngine/PerformanceMonitor.swift",
                "Services/Export/ExportModels.swift",
                "Services/Export/ExportManager.swift",
                "Services/Export/TextExporter.swift",
                "Services/Export/MarkdownExporter.swift",
                "Services/Export/PDFExporter.swift",
                "Features/MenuBar/MenuBarController.swift",
                "Features/Settings/SettingsView.swift",
                "Features/FloatingWidget/FloatingWidgetController.swift",
                "Features/FloatingWidget/FloatingWidgetWindow.swift",
                "Services/SettingsService.swift",
                "Services/SessionStorageService.swift",
                "Services/HotkeyService.swift",
                "Services/LaunchAtLoginService.swift",
                "Parallel/AsyncTranscriptionProcessor.swift"
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("DeprecateApplicationMain"),
                .enableUpcomingFeature("GlobalConcurrency"),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .define("SWIFT_CONCURRENCY_STRICT"),
                .define("VOICEFLOW_PRODUCTION")
            ],
            linkerSettings: [
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)