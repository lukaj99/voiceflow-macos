# Dependency Injection Container Guide

Thread-safe dependency injection system using the ServiceLocator pattern with protocol-based architecture.

## Overview

The DI container provides:
- ✅ Type-safe service registration and resolution
- ✅ Singleton and transient lifecycle management
- ✅ Lazy initialization support
- ✅ Module-based organization
- ✅ Mock injection for testing
- ✅ Thread-safe actor implementation

## Quick Start

### Basic Registration and Resolution

```swift
// Register a service
try await ServiceLocator.shared.register(AudioServiceProtocol.self) {
    AudioManager()
}

// Resolve a service
let audioService = try await ServiceLocator.shared.resolve(AudioServiceProtocol.self)
```

### Singleton vs Transient

```swift
// Singleton (default) - same instance every time
try await ServiceLocator.shared.register(SettingsServiceProtocol.self, isSingleton: true) {
    SettingsService()
}

// Transient - new instance every time
try await ServiceLocator.shared.register(RequestHandlerProtocol.self, isSingleton: false) {
    RequestHandler()
}
```

### Register Instance

```swift
// Register an existing instance
let settings = SettingsService()
try await ServiceLocator.shared.registerInstance(SettingsServiceProtocol.self, instance: settings)
```

## Module-Based Organization

Organize related services into modules:

```swift
struct AudioModule: ServiceModule {
    let name = "Audio"

    func registerServices(in locator: ServiceLocator) async throws {
        // Register audio-related services
        try await locator.register(AudioServiceProtocol.self) {
            AudioManager()
        }

        try await locator.register(AudioBufferPoolProtocol.self) {
            AudioBufferPool()
        }
    }
}

// Register the module
try await ServiceLocator.shared.register(module: AudioModule())
```

### Module Dependencies

```swift
struct TranscriptionModule: ServiceModule {
    let name = "Transcription"

    // Declare dependencies
    var dependencies: [any ServiceModule.Type] {
        [AudioModule.self, CoreModule.self]
    }

    func registerServices(in locator: ServiceLocator) async throws {
        try await locator.register(TranscriptionServiceProtocol.self) {
            // Dependencies are guaranteed to be registered
            let audio = try await locator.resolve(AudioServiceProtocol.self)
            let settings = try await locator.resolve(SettingsServiceProtocol.self)
            return TranscriptionEngine(audio: audio, settings: settings)
        }
    }
}

// Auto-sorted by dependencies
try await ServiceLocator.shared.registerModules([
    TranscriptionModule(),
    AudioModule(),
    CoreModule()
])
```

## Dependency Injection Patterns

### Constructor Injection (Recommended)

```swift
class TranscriptionViewModel {
    private let transcriptionService: TranscriptionServiceProtocol
    private let audioService: AudioServiceProtocol

    init(
        transcriptionService: TranscriptionServiceProtocol,
        audioService: AudioServiceProtocol
    ) {
        self.transcriptionService = transcriptionService
        self.audioService = audioService
    }
}

// Register with dependencies
try await ServiceLocator.shared.register(TranscriptionViewModel.self) {
    let transcription = try await ServiceLocator.shared.resolve(TranscriptionServiceProtocol.self)
    let audio = try await ServiceLocator.shared.resolve(AudioServiceProtocol.self)
    return TranscriptionViewModel(
        transcriptionService: transcription,
        audioService: audio
    )
}
```

### Service Locator Pattern (When Needed)

```swift
class FeatureCoordinator {
    private let locator: ServiceLocator

    init(locator: ServiceLocator = .shared) {
        self.locator = locator
    }

    func startFeature() async throws {
        let service = try await locator.resolve(FeatureServiceProtocol.self)
        try await service.start()
    }
}
```

## Testing with Mocks

### Mock Service

```swift
class MockTranscriptionService: TranscriptionServiceProtocol {
    var startCallCount = 0
    var mockResults: [TranscriptionResult] = []

    func startTranscription(configuration: Configuration) async throws -> AsyncStream<TranscriptionResult> {
        startCallCount += 1
        return AsyncStream { continuation in
            for result in mockResults {
                continuation.yield(result)
            }
            continuation.finish()
        }
    }

    // ... implement other required methods
}
```

### Test Setup

```swift
class MyFeatureTests: XCTestCase {
    var locator: ServiceLocator!

    override func setUp() async throws {
        // Create fresh test instance
        locator = ServiceLocator.createTestInstance()

        // Register mocks
        let mock = MockTranscriptionService()
        try await locator.registerInstance(TranscriptionServiceProtocol.self, instance: mock)

        // Register system under test
        try await locator.register(MyFeature.self) {
            let service = try await self.locator.resolve(TranscriptionServiceProtocol.self)
            return MyFeature(transcription: service)
        }
    }

    func testMyFeature() async throws {
        let sut = try await locator.resolve(MyFeature.self)

        // Test with mock
        await sut.performAction()

        let mock = try await locator.resolve(TranscriptionServiceProtocol.self) as! MockTranscriptionService
        XCTAssertEqual(mock.startCallCount, 1)
    }
}
```

### Replace Existing Service

```swift
// In test
try await locator.replaceMock(AudioServiceProtocol.self, mock: mockAudio)

// Or with factory
try await locator.replace(AudioServiceProtocol.self) {
    MockAudioService()
}
```

## Best Practices

### 1. Protocol-First Design
Always register protocols, not concrete types:

```swift
// ✅ Good
try await locator.register(AudioServiceProtocol.self) { AudioManager() }

// ❌ Bad
try await locator.register(AudioManager.self) { AudioManager() }
```

### 2. Constructor Injection Over Service Locator
Prefer injecting dependencies through constructors:

```swift
// ✅ Good - testable, explicit dependencies
class Feature {
    init(audio: AudioServiceProtocol) { ... }
}

// ❌ Bad - hidden dependencies, harder to test
class Feature {
    func start() {
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
    }
}
```

### 3. Use Modules for Organization
Group related services:

```swift
struct AudioModule: ServiceModule {
    // All audio-related services in one place
}
```

### 4. Default to Singletons
Use singletons unless you need new instances:

```swift
// Most services should be singletons
try await locator.register(SettingsServiceProtocol.self) {
    SettingsService()
}
```

### 5. Inject ServiceLocator for Coordinators
Coordinators can use ServiceLocator directly:

```swift
class AppCoordinator {
    private let locator: ServiceLocator

    init(locator: ServiceLocator = .shared) {
        self.locator = locator
    }
}
```

## Error Handling

```swift
do {
    let service = try await locator.resolve(MyServiceProtocol.self)
} catch let error as ServiceLocator.ServiceLocatorError {
    switch error {
    case .serviceNotRegistered(let type):
        print("Service not found: \(type)")
    case .typeMismatch(let expected, let actual):
        print("Wrong type: expected \(expected), got \(actual)")
    case .factoryFailed(let type, let error):
        print("Failed to create \(type): \(error)")
    case .duplicateRegistration(let type):
        print("Already registered: \(type)")
    }
}
```

## Architecture Integration

### Application Startup

```swift
@main
struct VoiceFlowApp: App {
    init() {
        Task {
            try await setupDependencies()
        }
    }

    private func setupDependencies() async throws {
        let locator = ServiceLocator.shared

        // Register all modules
        try await locator.registerModules([
            CoreModule(),
            AudioModule(),
            TranscriptionModule(),
            UIModule()
        ])
    }
}
```

### SwiftUI Integration

```swift
struct ContentView: View {
    @State private var viewModel: ContentViewModel?

    var body: some View {
        if let viewModel {
            ContentViewImpl(viewModel: viewModel)
        }
    }
    .task {
        viewModel = try? await ServiceLocator.shared.resolve(ContentViewModel.self)
    }
}
```

## Thread Safety

ServiceLocator is implemented as an actor, ensuring thread-safe access:

```swift
// Safe to call from multiple tasks
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10 {
        group.addTask {
            let service = try await ServiceLocator.shared.resolve(MyServiceProtocol.self)
            await service.doWork()
        }
    }
}
```

## Performance Considerations

- **Singletons**: Created once, cached for subsequent resolutions (fast)
- **Transients**: New instance on each resolution (slower)
- **Actor isolation**: Slight overhead for thread safety (minimal)

## Implementation Details

### Files

- **ServiceLocator.swift** - Core DI container with actor-based thread safety
- **ServiceModule.swift** - Module protocol and dependency management
- **ServiceLocatorTests.swift** - Comprehensive test suite (17+ tests)

### Key Features

1. **Type Safety** - Compile-time type checking for service resolution
2. **Thread Safety** - Actor-based implementation ensures no data races
3. **Module System** - Organize services into logical groups
4. **Dependency Ordering** - Automatic topological sort of module dependencies
5. **Test Support** - Built-in mock injection and test instance creation
6. **Error Reporting** - Clear, actionable error messages

## Testing Coverage

The test suite covers:
- Basic registration and resolution
- Singleton vs transient lifecycle
- Dependency injection
- Module registration with dependencies
- Mock injection and replacement
- Error handling and descriptions
- Thread safety with concurrent access
- Service management (unregister, reset, isRegistered)
- Optional resolution

## Troubleshooting

### "Service not registered"
- Check service is registered before resolving
- Verify module dependencies are correct
- Use `isRegistered()` to check registration status

### "Type mismatch"
- Ensure factory returns correct type
- Check protocol conformance

### "Duplicate registration"
- Use `unregister()` before re-registering
- Or use `replace()` for testing

### Circular Dependencies
- Refactor to break cycle
- Use property injection instead of constructor injection
- Consider creating a coordinator to manage lifecycle
