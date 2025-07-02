import Foundation

/// Core service module for registering all application services
public struct CoreServiceModule: DIModule {
    
    public static func register(in container: DIContainer) {
        let factory = ServiceFactory(container: container)
        
        // Register core services as lazy singletons
        container.registerLazySingleton({
            factory.createSettingsService()
        }, for: SettingsServiceProtocol.self)
        
        container.registerLazySingleton({
            factory.createSessionStorageService()
        }, for: SessionStorageServiceProtocol.self)
        
        container.registerLazySingleton({
            factory.createHotkeyService()
        }, for: HotkeyServiceProtocol.self)
        
        container.registerLazySingleton({
            factory.createLaunchAtLoginService()
        }, for: LaunchAtLoginServiceProtocol.self)
    }
}

/// UI service module for registering UI-related services
public struct UIServiceModule: DIModule {
    
    public static func register(in container: DIContainer) {
        // Register UI-specific services here
        // Example: Window managers, view model factories, etc.
    }
}

/// Transcription service module for registering transcription-related services
public struct TranscriptionServiceModule: DIModule {
    
    public static func register(in container: DIContainer) {
        // Register transcription engine and related services
        // This will be implemented by another agent
    }
}

/// Export service module for registering export-related services
public struct ExportServiceModule: DIModule {
    
    public static func register(in container: DIContainer) {
        // Register export manager and exporter implementations
        // This will be implemented by another agent
    }
}

// MARK: - Module Manager

/// Manager for organizing and registering service modules
public final class ModuleManager {
    
    private let container: DIContainer
    
    public init(container: DIContainer = .shared) {
        self.container = container
    }
    
    /// Register all core modules
    public func registerCoreModules() {
        container.register(modules: [
            CoreServiceModule.self,
            UIServiceModule.self,
            TranscriptionServiceModule.self,
            ExportServiceModule.self
        ])
    }
    
    /// Register a specific module
    public func register(module: DIModule.Type) {
        container.register(module: module)
    }
    
    /// Register modules conditionally based on configuration
    public func registerModules(configuration: AppConfiguration) {
        // Always register core services
        register(module: CoreServiceModule.self)
        
        // Conditionally register other modules
        if configuration.enableUI {
            register(module: UIServiceModule.self)
        }
        
        if configuration.enableTranscription {
            register(module: TranscriptionServiceModule.self)
        }
        
        if configuration.enableExport {
            register(module: ExportServiceModule.self)
        }
    }
}

// MARK: - App Configuration

public struct AppConfiguration {
    public let enableUI: Bool
    public let enableTranscription: Bool
    public let enableExport: Bool
    public let enableDeveloperMode: Bool
    
    public init(
        enableUI: Bool = true,
        enableTranscription: Bool = true,
        enableExport: Bool = true,
        enableDeveloperMode: Bool = false
    ) {
        self.enableUI = enableUI
        self.enableTranscription = enableTranscription
        self.enableExport = enableExport
        self.enableDeveloperMode = enableDeveloperMode
    }
    
    public static var `default`: AppConfiguration {
        AppConfiguration()
    }
    
    public static var testing: AppConfiguration {
        AppConfiguration(
            enableUI: false,
            enableTranscription: true,
            enableExport: true,
            enableDeveloperMode: true
        )
    }
}