import Foundation

/// Main dependency injection container for VoiceFlow
/// Provides thread-safe service registration and resolution with support for both singleton and factory patterns
@MainActor
public final class DIContainer: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DIContainer()
    
    // MARK: - Private Properties
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a singleton service instance
    /// - Parameters:
    ///   - service: The service instance to register
    ///   - protocol: The protocol type the service conforms to
    public func register<T>(_ service: T, for protocol: T.Type) {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        services[key] = service
    }
    
    /// Register a factory for creating service instances
    /// - Parameters:
    ///   - factory: A closure that creates a new instance of the service
    ///   - protocol: The protocol type the service conforms to
    public func registerFactory<T>(_ factory: @escaping () -> T, for protocol: T.Type) {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
    }
    
    /// Register a lazy singleton - created on first resolve
    /// - Parameters:
    ///   - factory: A closure that creates the singleton instance
    ///   - protocol: The protocol type the service conforms to
    public func registerLazySingleton<T>(_ factory: @escaping () -> T, for protocol: T.Type) {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        
        factories[key] = { [weak self] in
            guard let self = self else { fatalError("DIContainer deallocated") }
            
            // Check if already created
            if let existing = self.services[key] {
                return existing
            }
            
            // Create and store
            let instance = factory()
            self.services[key] = instance
            return instance
        }
    }
    
    // MARK: - Resolution
    
    /// Resolve a service by its protocol type
    /// - Parameter protocol: The protocol type to resolve
    /// - Returns: The service instance conforming to the protocol
    /// - Throws: DIError if the service is not registered
    public func resolve<T>(_ protocol: T.Type) throws -> T {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        
        // Check for singleton instance
        if let service = services[key] as? T {
            return service
        }
        
        // Check for factory
        if let factory = factories[key] {
            guard let service = factory() as? T else {
                throw DIError.typeMismatch(expected: String(describing: T.self))
            }
            return service
        }
        
        throw DIError.serviceNotRegistered(String(describing: T.self))
    }
    
    /// Resolve a service safely, returning nil if not registered
    /// - Parameter protocol: The protocol type to resolve
    /// - Returns: The service instance or nil
    public func resolveOptional<T>(_ protocol: T.Type) -> T? {
        try? resolve(`protocol`)
    }
    
    // MARK: - Utilities
    
    /// Check if a service is registered
    /// - Parameter protocol: The protocol type to check
    /// - Returns: True if the service is registered
    public func isRegistered<T>(_ protocol: T.Type) -> Bool {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        return services[key] != nil || factories[key] != nil
    }
    
    /// Remove a registered service
    /// - Parameter protocol: The protocol type to remove
    public func unregister<T>(_ protocol: T.Type) {
        let key = String(describing: `protocol`)
        lock.lock()
        defer { lock.unlock() }
        services.removeValue(forKey: key)
        factories.removeValue(forKey: key)
    }
    
    /// Remove all registered services and factories
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
        factories.removeAll()
    }
    
    // MARK: - Batch Registration
    
    /// Register multiple services at once
    /// - Parameter registrations: Array of registration closures
    public func registerServices(_ registrations: [() -> Void]) {
        registrations.forEach { $0() }
    }
}

// MARK: - Errors

public enum DIError: LocalizedError {
    case serviceNotRegistered(String)
    case typeMismatch(expected: String)
    case circularDependency(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let type):
            return "Service not registered for type: \(type)"
        case .typeMismatch(let expected):
            return "Type mismatch. Expected: \(expected)"
        case .circularDependency(let type):
            return "Circular dependency detected for type: \(type)"
        }
    }
}

// MARK: - Property Wrapper

/// Property wrapper for dependency injection
@propertyWrapper
public struct Injected<T> {
    private let container: DIContainer
    private var service: T?
    
    public init(container: DIContainer = .shared) {
        self.container = container
    }
    
    public var wrappedValue: T {
        mutating get {
            if service == nil {
                do {
                    service = try container.resolve(T.self)
                } catch {
                    fatalError("Failed to resolve \(T.self): \(error)")
                }
            }
            return service!
        }
    }
    
    public mutating func inject(_ value: T) {
        service = value
    }
}

// MARK: - Module Registration Protocol

/// Protocol for modules that can register their services
public protocol DIModule {
    static func register(in container: DIContainer)
}

// MARK: - Container Extensions

extension DIContainer {
    /// Register a module's services
    /// - Parameter module: The module type to register
    public func register(module: DIModule.Type) {
        module.register(in: self)
    }
    
    /// Register multiple modules
    /// - Parameter modules: Array of module types to register
    public func register(modules: [DIModule.Type]) {
        modules.forEach { register(module: $0) }
    }
}