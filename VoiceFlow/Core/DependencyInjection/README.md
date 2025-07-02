# VoiceFlow Dependency Injection Architecture

This directory contains the core dependency injection (DI) infrastructure for VoiceFlow. The DI system provides a clean, testable, and maintainable way to manage service dependencies throughout the application.

## Core Components

### DIContainer
The main dependency injection container that manages service registration and resolution.

**Key Features:**
- Thread-safe service registration and resolution
- Support for both singleton and factory patterns
- Lazy singleton support for deferred initialization
- Property wrapper support with `@Injected`

### Service Protocols
Located in `/Core/Protocols/`, these define the contracts for all services:
- `SettingsServiceProtocol` - App settings management
- `SessionStorageServiceProtocol` - Transcription session storage
- `HotkeyServiceProtocol` - Global hotkey management
- `LaunchAtLoginServiceProtocol` - Launch at login functionality

### ServiceFactory
Factory class for creating and configuring service instances with proper dependency injection.

### ServiceModule
Modular organization of service registration using the DIModule protocol.

### DIBootstrap
Bootstrap class for initializing the DI container during application startup.

## Usage Examples

### Basic Service Registration and Resolution

```swift
// Register a service
let container = DIContainer.shared
container.register(SettingsService(), for: SettingsServiceProtocol.self)

// Resolve a service
let settings = try container.resolve(SettingsServiceProtocol.self)
```

### Using Property Wrapper

```swift
class MyViewModel {
    @Injected var settings: SettingsServiceProtocol
    @Injected var sessionStorage: SessionStorageServiceProtocol
    
    func updateSettings() {
        settings.enableRealTimeTranscription = true
    }
}
```

### Application Bootstrap

```swift
// In your app delegate or main entry point
@main
struct VoiceFlowApp: App {
    init() {
        // Bootstrap DI container
        DIBootstrap().bootstrap()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Module-based Registration

```swift
// Define a custom module
struct MyFeatureModule: DIModule {
    static func register(in container: DIContainer) {
        container.registerLazySingleton({
            MyFeatureService()
        }, for: MyFeatureServiceProtocol.self)
    }
}

// Register the module
container.register(module: MyFeatureModule.self)
```

### Testing with Mock Services

```swift
// In your test setup
class MyServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        // Reset container
        DIContainer.shared.reset()
        
        // Register mock services
        DIContainer.shared.register(
            MockSettingsService(), 
            for: SettingsServiceProtocol.self
        )
    }
}
```

## Best Practices

1. **Always use protocols** - Register and resolve services by their protocol types, not concrete implementations
2. **Prefer constructor injection** - Pass dependencies through initializers when possible
3. **Use lazy singletons** - For services that are expensive to create or may not be used
4. **Organize with modules** - Group related service registrations into modules
5. **Test with mocks** - Replace real services with mocks in tests

## Migration Guide

To migrate existing code to use DI:

1. Extract service protocols from existing services
2. Update service references to use protocols
3. Register services in the appropriate module
4. Replace direct instantiation with DI resolution

Example migration:
```swift
// Before
class MyView {
    let settings = SettingsService()
}

// After
class MyView {
    @Injected var settings: SettingsServiceProtocol
}
```

## Thread Safety

The DIContainer is thread-safe for all operations. However, services themselves should be marked with appropriate concurrency annotations:
- Use `@MainActor` for UI-bound services
- Implement `Sendable` for services that can be safely shared across actors

## Performance Considerations

- Singleton services are created once and cached
- Factory services create new instances on each resolution
- Lazy singletons defer creation until first use
- Property wrapper resolution is cached after first access