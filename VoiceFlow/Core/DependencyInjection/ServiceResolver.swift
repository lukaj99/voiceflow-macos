import Foundation

/// Utility class for cleaner service resolution syntax
/// Provides static methods and computed properties for common service access patterns
@MainActor
public struct ServiceResolver {
    
    private let container: DIContainer
    
    // MARK: - Initialization
    
    public init(container: DIContainer = .shared) {
        self.container = container
    }
    
    // MARK: - Generic Resolution
    
    /// Resolve a service with throwing syntax
    public func resolve<T>(_ type: T.Type) throws -> T {
        try container.resolve(type)
    }
    
    /// Resolve a service with optional syntax
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        container.resolveOptional(type)
    }
    
    /// Resolve a service with force unwrapping (use with caution)
    public func resolveRequired<T>(_ type: T.Type) -> T {
        do {
            return try container.resolve(type)
        } catch {
            fatalError("Required service \(type) not found: \(error)")
        }
    }
}

// MARK: - Static Resolver

/// Static resolver for convenient access
public enum Resolver {
    
    // MARK: - Core Services
    
    public static var settings: SettingsServiceProtocol {
        ServiceResolver().resolveRequired(SettingsServiceProtocol.self)
    }
    
    public static var sessionStorage: SessionStorageServiceProtocol {
        ServiceResolver().resolveRequired(SessionStorageServiceProtocol.self)
    }
    
    public static var hotkeys: HotkeyServiceProtocol {
        ServiceResolver().resolveRequired(HotkeyServiceProtocol.self)
    }
    
    public static var launchAtLogin: LaunchAtLoginServiceProtocol {
        ServiceResolver().resolveRequired(LaunchAtLoginServiceProtocol.self)
    }
    
    // MARK: - Optional Services
    
    public static var settingsOptional: SettingsServiceProtocol? {
        ServiceResolver().resolveOptional(SettingsServiceProtocol.self)
    }
    
    public static var sessionStorageOptional: SessionStorageServiceProtocol? {
        ServiceResolver().resolveOptional(SessionStorageServiceProtocol.self)
    }
    
    public static var hotkeysOptional: HotkeyServiceProtocol? {
        ServiceResolver().resolveOptional(HotkeyServiceProtocol.self)
    }
    
    public static var launchAtLoginOptional: LaunchAtLoginServiceProtocol? {
        ServiceResolver().resolveOptional(LaunchAtLoginServiceProtocol.self)
    }
    
    // MARK: - Generic Resolution
    
    public static func resolve<T>(_ type: T.Type) throws -> T {
        try ServiceResolver().resolve(type)
    }
    
    public static func resolveOptional<T>(_ type: T.Type) -> T? {
        ServiceResolver().resolveOptional(type)
    }
    
    public static func resolveRequired<T>(_ type: T.Type) -> T {
        ServiceResolver().resolveRequired(type)
    }
}

// MARK: - SwiftUI Environment Integration

import SwiftUI

/// Environment key for dependency injection container
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

/// Environment key for service resolver
private struct ServiceResolverKey: EnvironmentKey {
    static let defaultValue = ServiceResolver()
}

extension EnvironmentValues {
    /// Access to the DI container from SwiftUI views
    public var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
    
    /// Access to the service resolver from SwiftUI views
    public var serviceResolver: ServiceResolver {
        get { self[ServiceResolverKey.self] }
        set { self[ServiceResolverKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Inject a custom DI container into the view hierarchy
    public func diContainer(_ container: DIContainer) -> some View {
        environment(\.diContainer, container)
    }
    
    /// Inject a custom service resolver into the view hierarchy
    public func serviceResolver(_ resolver: ServiceResolver) -> some View {
        environment(\.serviceResolver, resolver)
    }
}

// MARK: - Property Wrapper for SwiftUI

/// Property wrapper for resolving services in SwiftUI views
@propertyWrapper
public struct InjectedService<Service>: DynamicProperty {
    @Environment(\.serviceResolver) private var resolver
    
    private let serviceType: Service.Type
    private var resolvedService: Service?
    
    public init(_ serviceType: Service.Type) {
        self.serviceType = serviceType
    }
    
    public var wrappedValue: Service {
        if let service = resolvedService {
            return service
        }
        
        guard let service = resolver.resolveOptional(serviceType) else {
            fatalError("Service \(serviceType) not registered in DI container")
        }
        
        return service
    }
}

// MARK: - Usage Examples

/*
// In a SwiftUI View:
struct MyView: View {
    @InjectedService(SettingsServiceProtocol.self) var settings
    @InjectedService(SessionStorageServiceProtocol.self) var sessionStorage
    
    var body: some View {
        Text("Language: \(settings.selectedLanguage)")
    }
}

// In a regular class:
class MyController {
    private let settings = Resolver.settings
    private let sessionStorage = Resolver.sessionStorage
    
    func doSomething() {
        let language = settings.selectedLanguage
        // ...
    }
}

// With optional resolution:
if let hotkeys = Resolver.hotkeysOptional {
    hotkeys.pauseAllHotkeys()
}

// With generic resolution:
let customService = try Resolver.resolve(MyCustomServiceProtocol.self)
*/