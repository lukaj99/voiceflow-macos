# VoiceFlowKit Architecture Plan

## Overview

This document outlines the target architecture for VoiceFlow, modeled after BatFi's BatFiKit pattern. The goal is to create a modular, testable, and maintainable codebase using Swift Package Manager local packages.

## Current State

```
VoiceFlow/
├── App/                      # Entry point (good)
├── Core/                     # Mixed responsibilities
│   ├── AppState.swift       # Too large, many concerns
│   ├── Architecture/        # DI & protocols (good start)
│   ├── ErrorHandling/       # Error types (good)
│   ├── Performance/         # Metrics (can be its own module)
│   └── Validation/          # Input validation (can merge)
├── Services/                 # All services mixed together
├── ViewModels/              # View models
├── Views/                   # SwiftUI views
└── Models/                  # Data models (too sparse)
```

## Target State: VoiceFlowKit

```
VoiceFlowKit/                    # Local Swift Package
├── Sources/
│   ├── App/                     # Main app coordinator
│   ├── AppCore/                 # Core business logic
│   ├── Audio/                   # Audio capture & processing
│   ├── Clients/                 # Protocol definitions (DI interfaces)
│   ├── ClientsLive/             # Live implementations
│   ├── Export/                  # Document export
│   ├── LLM/                     # LLM integration
│   ├── Settings/                # Settings UI
│   ├── Shared/                  # Shared types & utilities
│   ├── SharedUI/                # Reusable UI components
│   └── Transcription/           # Transcription services
└── Tests/
    └── VoiceFlowKitTests/

VoiceFlow/                        # Main App Target
├── App/
│   ├── main.swift
│   └── VoiceFlowApp.swift
└── Resources/
    └── Assets.xcassets
```

## Module Definitions

### Clients (Protocol Definitions)

All service interfaces. Uses `swift-dependencies` for DI.

```swift
// VoiceFlowKit/Sources/Clients/AudioClient.swift
import Dependencies
import DependenciesMacros

@DependencyClient
public struct AudioClient: Sendable {
    public var startRecording: @Sendable () async throws -> Void
    public var stopRecording: @Sendable () -> Void
    public var audioLevelStream: @Sendable () -> AsyncStream<Float>
    public var isRecording: @Sendable () -> Bool
}

extension AudioClient: DependencyKey {
    public static let liveValue = AudioClient.live
    public static let testValue = AudioClient.mock
}
```

```swift
// VoiceFlowKit/Sources/Clients/TranscriptionClient.swift
@DependencyClient
public struct TranscriptionClient: Sendable {
    public var connect: @Sendable (String) async throws -> Void
    public var disconnect: @Sendable () async -> Void
    public var send: @Sendable (Data) async -> Void
    public var transcriptStream: @Sendable () -> AsyncStream<TranscriptSegment>
}
```

```swift
// VoiceFlowKit/Sources/Clients/LLMClient.swift
@DependencyClient
public struct LLMClient: Sendable {
    public var process: @Sendable (String, LLMProvider, String) async throws -> String
    public var availableProviders: @Sendable () -> [LLMProvider]
}
```

```swift
// VoiceFlowKit/Sources/Clients/CredentialClient.swift
@DependencyClient
public struct CredentialClient: Sendable {
    public var getAPIKey: @Sendable (ServiceType) throws -> String?
    public var setAPIKey: @Sendable (String, ServiceType) throws -> Void
    public var deleteAPIKey: @Sendable (ServiceType) throws -> Void
}
```

### ClientsLive (Live Implementations)

Real implementations of all clients.

```swift
// VoiceFlowKit/Sources/ClientsLive/AudioClient+Live.swift
import AVFoundation
import Clients

extension AudioClient {
    public static var live: AudioClient {
        let manager = AudioManager()
        return AudioClient(
            startRecording: { try await manager.startRecording() },
            stopRecording: { manager.stopRecording() },
            audioLevelStream: { manager.audioLevelStream },
            isRecording: { manager.isRecording }
        )
    }
}
```

### AppCore (Business Logic)

Core coordinator and state management.

```swift
// VoiceFlowKit/Sources/AppCore/TranscriptionCoordinator.swift
import Dependencies
import Clients

@MainActor
@Observable
public final class TranscriptionCoordinator {
    @Dependency(\.audioClient) var audio
    @Dependency(\.transcriptionClient) var transcription
    @Dependency(\.credentialClient) var credentials

    public private(set) var transcriptionText: String = ""
    public private(set) var isRecording: Bool = false
    public private(set) var audioLevel: Float = 0.0

    public func startTranscription() async throws {
        guard let apiKey = try credentials.getAPIKey(.deepgram) else {
            throw VoiceFlowError.apiKeyMissing
        }
        try await transcription.connect(apiKey)
        try await audio.startRecording()
        isRecording = true
    }
}
```

### Shared (Common Types)

Types used across modules.

```swift
// VoiceFlowKit/Sources/Shared/TranscriptSegment.swift
public struct TranscriptSegment: Sendable, Equatable {
    public let text: String
    public let timestamp: Date
    public let isFinal: Bool
    public let confidence: Double
}

// VoiceFlowKit/Sources/Shared/LLMProvider.swift
public enum LLMProvider: String, Sendable, CaseIterable {
    case openai
    case claude
    case ollama
}

// VoiceFlowKit/Sources/Shared/ServiceType.swift
public enum ServiceType: String, Sendable {
    case deepgram
    case openai
    case claude
}
```

### Audio (Audio Processing)

Audio capture, format conversion, level metering.

```swift
// VoiceFlowKit/Sources/Audio/AudioManager.swift
import AVFoundation

public actor AudioManager {
    private var engine: AVAudioEngine?
    private var levelContinuation: AsyncStream<Float>.Continuation?

    public var audioLevelStream: AsyncStream<Float> {
        AsyncStream { continuation in
            self.levelContinuation = continuation
        }
    }

    public func startRecording() async throws {
        // Implementation
    }
}
```

### Transcription (Deepgram Integration)

WebSocket connection and response parsing.

```swift
// VoiceFlowKit/Sources/Transcription/DeepgramService.swift
public actor DeepgramService {
    private var websocket: WebSocket?

    public func connect(apiKey: String) async throws
    public func send(_ data: Data) async
    public func disconnect() async

    public var transcriptStream: AsyncStream<TranscriptSegment>
}
```

### LLM (LLM Integration)

Provider-agnostic LLM processing.

```swift
// VoiceFlowKit/Sources/LLM/LLMService.swift
public actor LLMService {
    public func process(
        text: String,
        provider: LLMProvider,
        model: String
    ) async throws -> String
}
```

### Export (Document Export)

PDF, DOCX, SRT, Markdown export.

```swift
// VoiceFlowKit/Sources/Export/ExportService.swift
public struct ExportService {
    public func export(
        _ text: String,
        format: ExportFormat,
        to url: URL
    ) async throws
}
```

## Package.swift

```swift
// VoiceFlowKit/Package.swift
// swift-tools-version: 6.0
import PackageDescription

extension Target.Dependency {
    static let appCore: Self = "AppCore"
    static let audio: Self = "Audio"
    static let clients: Self = "Clients"
    static let clientsLive: Self = "ClientsLive"
    static let export: Self = "Export"
    static let llm: Self = "LLM"
    static let settings: Self = "Settings"
    static let shared: Self = "Shared"
    static let sharedUI: Self = "SharedUI"
    static let transcription: Self = "Transcription"

    static let asyncAlgorithms: Self = .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
    static let dependencies: Self = .product(name: "Dependencies", package: "swift-dependencies")
    static let dependenciesMacros: Self = .product(name: "DependenciesMacros", package: "swift-dependencies")
}

let package = Package(
    name: "VoiceFlowKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "App", targets: ["App"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "Clients", targets: ["Clients"]),
        .library(name: "ClientsLive", targets: ["ClientsLive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
    ],
    targets: [
        // Shared types
        .target(name: "Shared"),

        // Client protocols
        .target(
            name: "Clients",
            dependencies: [
                .shared,
                .dependencies,
                .dependenciesMacros,
            ]
        ),

        // Live implementations
        .target(
            name: "ClientsLive",
            dependencies: [
                .clients,
                .audio,
                .transcription,
                .llm,
                .export,
                .asyncAlgorithms,
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),

        // Audio processing
        .target(
            name: "Audio",
            dependencies: [.shared, .asyncAlgorithms]
        ),

        // Transcription
        .target(
            name: "Transcription",
            dependencies: [.shared, .asyncAlgorithms]
        ),

        // LLM
        .target(
            name: "LLM",
            dependencies: [.shared]
        ),

        // Export
        .target(
            name: "Export",
            dependencies: [.shared]
        ),

        // Core business logic
        .target(
            name: "AppCore",
            dependencies: [
                .clients,
                .shared,
                .dependencies,
                .asyncAlgorithms,
            ]
        ),

        // Settings UI
        .target(
            name: "Settings",
            dependencies: [
                .appCore,
                .clients,
                .shared,
                .sharedUI,
            ]
        ),

        // Shared UI
        .target(name: "SharedUI"),

        // Main app
        .target(
            name: "App",
            dependencies: [
                .appCore,
                .clientsLive,
                .settings,
                .product(name: "HotKey", package: "HotKey"),
            ]
        ),

        // Tests
        .testTarget(
            name: "VoiceFlowKitTests",
            dependencies: [
                .appCore,
                .clients,
                .dependencies,
            ]
        ),
    ]
)
```

## Migration Strategy

### Phase 1: Add swift-dependencies (Low Risk)
1. Add swift-dependencies to Package.swift
2. Create Clients folder with protocol definitions
3. Create basic DI infrastructure
4. No changes to existing code

### Phase 2: Extract Shared Types (Low Risk)
1. Move common types to Shared
2. Update imports
3. Verify builds

### Phase 3: Create Client Implementations (Medium Risk)
1. Create ClientsLive with wrappers around existing services
2. Initially just wrap existing implementations
3. Gradually migrate to proper dependency injection

### Phase 4: Extract Audio Module (Medium Risk)
1. Move AudioManager and related code
2. Update imports and dependencies
3. Verify audio still works

### Phase 5: Extract Remaining Modules (Higher Risk)
1. Transcription
2. LLM
3. Export
4. Settings

### Phase 6: Refactor AppState (Higher Risk)
1. Split AppState into focused coordinators
2. Use dependency injection
3. Remove singleton pattern

## Testing Benefits

With swift-dependencies:

```swift
func test_startTranscription_success() async throws {
    let coordinator = withDependencies {
        $0.audioClient.startRecording = { }
        $0.transcriptionClient.connect = { _ in }
        $0.credentialClient.getAPIKey = { _ in "test-key" }
    } operation: {
        TranscriptionCoordinator()
    }

    try await coordinator.startTranscription()

    XCTAssertTrue(coordinator.isRecording)
}
```

## Timeline Estimate

- Phase 1-2: 1-2 hours (safe, incremental)
- Phase 3: 2-4 hours (medium complexity)
- Phase 4-5: 4-8 hours (requires careful testing)
- Phase 6: 4-6 hours (significant refactoring)

**Total: 11-20 hours** for full migration

## Recommendation

Start with **Phase 1-2** to establish the pattern without risk. This provides:
- Clear architecture direction
- swift-dependencies infrastructure
- Shared types module
- Foundation for future work

The remaining phases can be done incrementally as time permits.
