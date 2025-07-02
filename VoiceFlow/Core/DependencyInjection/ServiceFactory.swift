import Foundation

/// Factory for creating and configuring services
/// Provides centralized service creation with proper dependency injection
@MainActor
public final class ServiceFactory {
    
    // MARK: - Properties
    
    private let container: DIContainer
    
    // MARK: - Initialization
    
    public init(container: DIContainer = .shared) {
        self.container = container
    }
    
    // MARK: - Core Services
    
    /// Create and configure the settings service
    public func createSettingsService() -> SettingsServiceProtocol {
        // Check if LaunchAtLoginService is available
        let launchAtLoginService: LaunchAtLoginServiceProtocol?
        if container.isRegistered(LaunchAtLoginServiceProtocol.self) {
            launchAtLoginService = try? container.resolve(LaunchAtLoginServiceProtocol.self)
        } else {
            launchAtLoginService = nil
        }
        
        // Create the service with dependencies
        let service = SettingsService()
        
        // If we have a custom launch service, inject it (future enhancement)
        // For now, SettingsService creates its own
        
        return service
    }
    
    /// Create and configure the session storage service
    public func createSessionStorageService() -> SessionStorageServiceProtocol {
        return SessionStorageService()
    }
    
    /// Create and configure the hotkey service
    public func createHotkeyService() -> HotkeyServiceProtocol {
        return HotkeyService()
    }
    
    /// Create and configure the launch at login service
    public func createLaunchAtLoginService() -> LaunchAtLoginServiceProtocol {
        return LaunchAtLoginService()
    }
    
    // MARK: - Composite Services
    
    /// Create a service with dependencies
    /// - Parameters:
    ///   - type: The service type to create
    ///   - dependencies: Array of dependency types required
    /// - Returns: The created service
    /// - Throws: DIError if dependencies cannot be resolved
    public func createService<T>(
        _ type: T.Type,
        dependencies: [Any.Type] = []
    ) throws -> T {
        // Resolve dependencies first
        var resolvedDependencies: [Any] = []
        for dependencyType in dependencies {
            let dependency = try container.resolve(dependencyType)
            resolvedDependencies.append(dependency)
        }
        
        // Create service based on type
        switch type {
        case is SettingsServiceProtocol.Type:
            return createSettingsService() as! T
        case is SessionStorageServiceProtocol.Type:
            return createSessionStorageService() as! T
        case is HotkeyServiceProtocol.Type:
            return createHotkeyService() as! T
        case is LaunchAtLoginServiceProtocol.Type:
            return createLaunchAtLoginService() as! T
        default:
            throw DIError.serviceNotRegistered(String(describing: type))
        }
    }
}

// MARK: - Service Configuration

public struct ServiceConfiguration {
    public let enableLogging: Bool
    public let enableMetrics: Bool
    public let enableCaching: Bool
    
    public init(
        enableLogging: Bool = true,
        enableMetrics: Bool = false,
        enableCaching: Bool = true
    ) {
        self.enableLogging = enableLogging
        self.enableMetrics = enableMetrics
        self.enableCaching = enableCaching
    }
}

// MARK: - Factory Extensions

extension ServiceFactory {
    /// Register all core services in the container
    public func registerCoreServices() {
        // Register singletons
        container.registerLazySingleton({
            self.createSettingsService()
        }, for: SettingsServiceProtocol.self)
        
        container.registerLazySingleton({
            self.createSessionStorageService()
        }, for: SessionStorageServiceProtocol.self)
        
        container.registerLazySingleton({
            self.createHotkeyService()
        }, for: HotkeyServiceProtocol.self)
        
        container.registerLazySingleton({
            self.createLaunchAtLoginService()
        }, for: LaunchAtLoginServiceProtocol.self)
    }
    
    /// Create a configured service with custom configuration
    public func createConfiguredService<T>(
        _ type: T.Type,
        configuration: ServiceConfiguration
    ) throws -> T {
        let service = try createService(type)
        
        // Apply configuration if service supports it
        if let configurableService = service as? ConfigurableService {
            configurableService.configure(with: configuration)
        }
        
        return service
    }
}

// MARK: - Configurable Service Protocol

public protocol ConfigurableService {
    func configure(with configuration: ServiceConfiguration)
}