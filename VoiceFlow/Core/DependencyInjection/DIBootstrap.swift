import Foundation

/// Bootstrap class for initializing the dependency injection container
/// Provides a centralized place for application startup configuration
@MainActor
public final class DIBootstrap {
    
    private let container: DIContainer
    private let moduleManager: ModuleManager
    
    // MARK: - Initialization
    
    public init(container: DIContainer = .shared) {
        self.container = container
        self.moduleManager = ModuleManager(container: container)
    }
    
    // MARK: - Bootstrap Methods
    
    /// Bootstrap the application with default configuration
    public func bootstrap() {
        bootstrapWithConfiguration(AppConfiguration.default)
    }
    
    /// Bootstrap the application with custom configuration
    public func bootstrapWithConfiguration(_ configuration: AppConfiguration) {
        // Clear any existing registrations
        container.reset()
        
        // Register modules based on configuration
        moduleManager.registerModules(configuration: configuration)
        
        // Perform any additional setup
        configureServices(configuration: configuration)
        
        // Validate container state
        validateContainer()
    }
    
    /// Bootstrap for testing with mock services
    public func bootstrapForTesting() {
        // Clear any existing registrations
        container.reset()
        
        // Register test configuration
        bootstrapWithConfiguration(AppConfiguration.testing)
        
        // Override with mock services as needed
        registerMockServices()
    }
    
    // MARK: - Private Methods
    
    private func configureServices(configuration: AppConfiguration) {
        // Configure services based on app configuration
        if configuration.enableDeveloperMode {
            configureDeveloperMode()
        }
    }
    
    private func configureDeveloperMode() {
        // Enable developer mode in settings if available
        if let settings = container.resolveOptional(SettingsServiceProtocol.self) {
            settings.enableDeveloperMode = true
            settings.logLevel = .debug
        }
    }
    
    private func validateContainer() {
        // Validate that core services are registered
        let coreServices: [Any.Type] = [
            SettingsServiceProtocol.self,
            SessionStorageServiceProtocol.self,
            HotkeyServiceProtocol.self,
            LaunchAtLoginServiceProtocol.self
        ]
        
        for serviceType in coreServices {
            if !container.isRegistered(serviceType) {
                print("⚠️ Warning: Core service \(serviceType) is not registered")
            }
        }
    }
    
    private func registerMockServices() {
        // This method can be used to register mock services for testing
        // Example:
        // container.register(MockSettingsService(), for: SettingsServiceProtocol.self)
    }
}

// MARK: - Bootstrap Extensions

extension DIBootstrap {
    
    /// Convenience method to bootstrap and return configured container
    public static func configuredContainer(
        with configuration: AppConfiguration = .default
    ) -> DIContainer {
        let bootstrap = DIBootstrap()
        bootstrap.bootstrapWithConfiguration(configuration)
        return DIContainer.shared
    }
    
    /// Bootstrap with environment-based configuration
    public func bootstrapFromEnvironment() {
        let configuration = AppConfiguration(
            enableUI: ProcessInfo.processInfo.environment["DISABLE_UI"] == nil,
            enableTranscription: ProcessInfo.processInfo.environment["DISABLE_TRANSCRIPTION"] == nil,
            enableExport: ProcessInfo.processInfo.environment["DISABLE_EXPORT"] == nil,
            enableDeveloperMode: ProcessInfo.processInfo.environment["DEVELOPER_MODE"] == "true"
        )
        
        bootstrapWithConfiguration(configuration)
    }
}

// MARK: - Service Locator Pattern (Optional)

/// Service locator for convenient access to common services
/// Note: Prefer dependency injection over service locator pattern when possible
public struct ServiceLocator {
    
    private static let container = DIContainer.shared
    
    // MARK: - Core Services
    
    public static var settings: SettingsServiceProtocol {
        get throws {
            try container.resolve(SettingsServiceProtocol.self)
        }
    }
    
    public static var sessionStorage: SessionStorageServiceProtocol {
        get throws {
            try container.resolve(SessionStorageServiceProtocol.self)
        }
    }
    
    public static var hotkeys: HotkeyServiceProtocol {
        get throws {
            try container.resolve(HotkeyServiceProtocol.self)
        }
    }
    
    public static var launchAtLogin: LaunchAtLoginServiceProtocol {
        get throws {
            try container.resolve(LaunchAtLoginServiceProtocol.self)
        }
    }
    
    // MARK: - Safe Accessors
    
    public static var settingsOrNil: SettingsServiceProtocol? {
        container.resolveOptional(SettingsServiceProtocol.self)
    }
    
    public static var sessionStorageOrNil: SessionStorageServiceProtocol? {
        container.resolveOptional(SessionStorageServiceProtocol.self)
    }
    
    public static var hotkeysOrNil: HotkeyServiceProtocol? {
        container.resolveOptional(HotkeyServiceProtocol.self)
    }
    
    public static var launchAtLoginOrNil: LaunchAtLoginServiceProtocol? {
        container.resolveOptional(LaunchAtLoginServiceProtocol.self)
    }
}