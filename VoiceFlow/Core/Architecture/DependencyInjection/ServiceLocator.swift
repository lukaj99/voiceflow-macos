//
//  ServiceLocator.swift
//  VoiceFlow
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import Foundation

/// Thread-safe dependency injection container with type-safe service resolution
/// Implements ServiceLocator pattern with support for:
/// - Type-safe registration and resolution
/// - Lazy initialization
/// - Singleton pattern for global access
/// - Protocol-based dependency injection
/// - Mock injection for testing
actor ServiceLocator {

    // MARK: - Singleton Access

    /// Global shared instance for application-wide service access
    static let shared = ServiceLocator()

    // MARK: - Storage

    /// Storage for registered service factories
    private var factories: [String: ServiceFactory] = [:]

    /// Storage for singleton instances (lazy initialized)
    private var singletons: [String: Any] = [:]

    /// Storage for service metadata for debugging
    private var metadata: [String: ServiceMetadata] = [:]

    // MARK: - Types

    /// Factory closure for creating service instances
    private struct ServiceFactory {
        let create: () throws -> Any
        let isSingleton: Bool
    }

    /// Metadata about registered services
    private struct ServiceMetadata {
        let typeName: String
        let protocolName: String
        let registrationDate: Date
        let isSingleton: Bool
    }

    /// Errors that can occur during service registration or resolution
    enum ServiceLocatorError: Error, CustomStringConvertible {
        case serviceNotRegistered(String)
        case typeMismatch(expected: String, actual: String)
        case factoryFailed(String, Error)
        case duplicateRegistration(String)

        var description: String {
            switch self {
            case .serviceNotRegistered(let type):
                return "Service not registered: \(type). Use register() to register this service."
            case .typeMismatch(let expected, let actual):
                return "Type mismatch: expected \(expected), but got \(actual)"
            case .factoryFailed(let type, let error):
                return "Factory failed to create \(type): \(error.localizedDescription)"
            case .duplicateRegistration(let type):
                return "Service already registered: \(type). Use reset() to clear existing registration."
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Registers a service with a factory closure
    /// - Parameters:
    ///   - type: Protocol type to register
    ///   - isSingleton: Whether to create a single instance (default: true)
    ///   - factory: Closure that creates the service instance
    /// - Throws: ServiceLocatorError.duplicateRegistration if service already registered
    func register<T>(
        _ type: T.Type,
        isSingleton: Bool = true,
        factory: @escaping () throws -> T
    ) throws {
        let key = typeKey(for: type)

        // Prevent duplicate registration
        guard factories[key] == nil else {
            throw ServiceLocatorError.duplicateRegistration(key)
        }

        // Wrap factory with type erasure
        let wrappedFactory = ServiceFactory(
            create: { try factory() },
            isSingleton: isSingleton
        )

        factories[key] = wrappedFactory

        // Store metadata for debugging
        metadata[key] = ServiceMetadata(
            typeName: String(describing: type),
            protocolName: String(reflecting: type),
            registrationDate: Date(),
            isSingleton: isSingleton
        )
    }

    /// Registers a service instance directly (always singleton)
    /// - Parameters:
    ///   - type: Protocol type to register
    ///   - instance: The service instance
    /// - Throws: ServiceLocatorError.duplicateRegistration if service already registered
    func registerInstance<T>(_ type: T.Type, instance: T) throws {
        let key = typeKey(for: type)

        guard factories[key] == nil else {
            throw ServiceLocatorError.duplicateRegistration(key)
        }

        // Store instance directly
        singletons[key] = instance

        // Register a factory that returns the instance
        let wrappedFactory = ServiceFactory(
            create: { instance },
            isSingleton: true
        )

        factories[key] = wrappedFactory

        metadata[key] = ServiceMetadata(
            typeName: String(describing: type),
            protocolName: String(reflecting: type),
            registrationDate: Date(),
            isSingleton: true
        )
    }

    // MARK: - Resolution

    /// Resolves a service by protocol type
    /// - Parameter type: Protocol type to resolve
    /// - Returns: Service instance
    /// - Throws: ServiceLocatorError if service not found or creation fails
    func resolve<T>(_ type: T.Type) throws -> T {
        let key = typeKey(for: type)

        // Check for existing singleton
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Get factory
        guard let factory = factories[key] else {
            throw ServiceLocatorError.serviceNotRegistered(key)
        }

        // Create instance
        let instance: Any
        do {
            instance = try factory.create()
        } catch {
            throw ServiceLocatorError.factoryFailed(key, error)
        }

        // Verify type
        guard let typedInstance = instance as? T else {
            throw ServiceLocatorError.typeMismatch(
                expected: String(describing: type),
                actual: String(describing: Swift.type(of: instance))
            )
        }

        // Store singleton if needed
        if factory.isSingleton {
            singletons[key] = typedInstance
        }

        return typedInstance
    }

    /// Optional resolution that returns nil if service not registered
    /// - Parameter type: Protocol type to resolve
    /// - Returns: Service instance or nil if not found
    func resolveOptional<T>(_ type: T.Type) -> T? {
        try? resolve(type)
    }

    // MARK: - Management

    /// Removes a service registration
    /// - Parameter type: Protocol type to unregister
    func unregister<T>(_ type: T.Type) {
        let key = typeKey(for: type)
        factories.removeValue(forKey: key)
        singletons.removeValue(forKey: key)
        metadata.removeValue(forKey: key)
    }

    /// Removes all service registrations and instances
    func reset() {
        factories.removeAll()
        singletons.removeAll()
        metadata.removeAll()
    }

    /// Checks if a service is registered
    /// - Parameter type: Protocol type to check
    /// - Returns: true if service is registered
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = typeKey(for: type)
        return factories[key] != nil
    }

    /// Returns metadata about all registered services
    /// - Returns: Dictionary of service names and their metadata
    func registeredServices() -> [String: ServiceMetadata] {
        metadata
    }

    // MARK: - Private Helpers

    /// Generates a unique key for a service type
    private func typeKey<T>(for type: T.Type) -> String {
        String(reflecting: type)
    }
}

// MARK: - Convenience Extensions

extension ServiceLocator {

    /// Registers multiple services from a module
    /// - Parameter module: Service module to register
    /// - Throws: ServiceLocatorError if registration fails
    func register(module: ServiceModule) async throws {
        try await module.registerServices(in: self)
    }

    /// Registers services lazily - factory only called when resolved
    /// Useful for expensive initialization
    func registerLazy<T>(
        _ type: T.Type,
        factory: @escaping () async throws -> T
    ) throws {
        // Convert async factory to sync by storing a task
        var task: Task<T, Error>?

        try register(type, isSingleton: true) {
            if let existingTask = task {
                return try existingTask.value
            }

            let newTask = Task {
                try await factory()
            }
            task = newTask
            return try newTask.value
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension ServiceLocator {

    /// Creates a fresh instance for testing (bypasses singleton)
    static func createTestInstance() -> ServiceLocator {
        ServiceLocator()
    }

    /// Replaces a service registration (useful for mock injection)
    /// - Parameters:
    ///   - type: Protocol type to replace
    ///   - factory: New factory closure
    func replace<T>(
        _ type: T.Type,
        with factory: @escaping () throws -> T
    ) throws {
        let key = typeKey(for: type)

        // Remove existing
        factories.removeValue(forKey: key)
        singletons.removeValue(forKey: key)

        // Register new
        try register(type, factory: factory)
    }

    /// Replaces a service with a mock instance
    /// - Parameters:
    ///   - type: Protocol type to replace
    ///   - mock: Mock instance
    func replaceMock<T>(_ type: T.Type, mock: T) throws {
        unregister(type)
        try registerInstance(type, instance: mock)
    }
}
#endif
