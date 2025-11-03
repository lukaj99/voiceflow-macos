//
//  ServiceModule.swift
//  VoiceFlow
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import Foundation

/// Protocol for organizing service registrations into logical modules
/// Allows grouping related services and their dependencies together
/// Example: AudioModule, TranscriptionModule, NetworkModule, etc.
protocol ServiceModule: Sendable {

    /// Module name for identification and debugging
    var name: String { get }

    /// Registers all services provided by this module
    /// - Parameter locator: Service locator to register services in
    /// - Throws: ServiceLocator.ServiceLocatorError if registration fails
    func registerServices(in locator: ServiceLocator) async throws

    /// Optional: Dependencies required by this module
    /// Used to validate that required services are registered before this module
    var dependencies: [any ServiceModule.Type] { get }
}

extension ServiceModule {
    /// Default: No dependencies
    var dependencies: [any ServiceModule.Type] { [] }
}

// MARK: - Example Module Implementations

/// Example module for core services
/// Demonstrates how to group related service registrations
struct CoreServicesModule: ServiceModule {

    let name = "CoreServices"

    func registerServices(in locator: ServiceLocator) async throws {
        // Example: Register core services here
        // try await locator.register(SettingsServiceProtocol.self) {
        //     SettingsService()
        // }

        // try await locator.register(ErrorReportingProtocol.self) {
        //     ErrorReporter()
        // }
    }
}

/// Example module for audio services
/// Shows organization of audio-related dependencies
struct AudioServicesModule: ServiceModule {

    let name = "AudioServices"

    var dependencies: [any ServiceModule.Type] {
        [CoreServicesModule.self]
    }

    func registerServices(in locator: ServiceLocator) async throws {
        // Example: Register audio services
        // try await locator.register(AudioServiceProtocol.self) {
        //     let settings = try locator.resolve(SettingsServiceProtocol.self)
        //     return AudioManager(settings: settings)
        // }
    }
}

/// Example module for transcription services
/// Demonstrates dependency chain management
struct TranscriptionServicesModule: ServiceModule {

    let name = "TranscriptionServices"

    var dependencies: [any ServiceModule.Type] {
        [CoreServicesModule.self, AudioServicesModule.self]
    }

    func registerServices(in locator: ServiceLocator) async throws {
        // Example: Register transcription services
        // try await locator.register(TranscriptionServiceProtocol.self) {
        //     let audio = try locator.resolve(AudioServiceProtocol.self)
        //     let settings = try locator.resolve(SettingsServiceProtocol.self)
        //     return TranscriptionEngine(audio: audio, settings: settings)
        // }
    }
}

// MARK: - Module Registration Helper

extension ServiceLocator {

    /// Registers multiple modules in dependency order
    /// Automatically resolves and orders modules based on their dependencies
    /// - Parameter modules: Array of modules to register
    /// - Throws: ModuleRegistrationError if circular dependencies or registration fails
    func registerModules(_ modules: [any ServiceModule]) async throws {
        // Topological sort to ensure dependencies are registered first
        let sorted = try topologicalSort(modules: modules)

        // Register in dependency order
        for module in sorted {
            try await register(module: module)
        }
    }

    /// Performs topological sort on modules based on dependencies
    private func topologicalSort(modules: [any ServiceModule]) throws -> [any ServiceModule] {
        var result: [any ServiceModule] = []
        var visited: Set<String> = []
        var visiting: Set<String> = []

        func visit(_ module: any ServiceModule) throws {
            let moduleName = module.name

            // Detect circular dependencies
            guard !visiting.contains(moduleName) else {
                throw ModuleRegistrationError.circularDependency(moduleName)
            }

            // Skip if already processed
            guard !visited.contains(moduleName) else {
                return
            }

            visiting.insert(moduleName)

            // Visit dependencies first
            for depType in module.dependencies {
                // Find the dependency module in the input list
                guard let depModule = modules.first(where: { type(of: $0) == depType }) else {
                    throw ModuleRegistrationError.missingDependency(
                        module: moduleName,
                        dependency: String(describing: depType)
                    )
                }
                try visit(depModule)
            }

            visiting.remove(moduleName)
            visited.insert(moduleName)
            result.append(module)
        }

        for module in modules {
            try visit(module)
        }

        return result
    }
}

/// Errors that can occur during module registration
enum ModuleRegistrationError: Error, CustomStringConvertible {
    case circularDependency(String)
    case missingDependency(module: String, dependency: String)
    case registrationFailed(module: String, error: any Error)

    var description: String {
        switch self {
        case .circularDependency(let module):
            return "Circular dependency detected for module: \(module)"
        case .missingDependency(let module, let dependency):
            return "Module '\(module)' depends on '\(dependency)' which is not registered"
        case .registrationFailed(let module, let error):
            return "Failed to register module '\(module)': \(error.localizedDescription)"
        }
    }
}
