import Dependencies
import DependenciesMacros
import Foundation

// MARK: - ServiceType

/// Types of services that require credentials.
public enum ServiceType: String, Sendable, CaseIterable {
    case deepgram
    case openai
    case claude

    public var displayName: String {
        switch self {
        case .deepgram: return "Deepgram"
        case .openai: return "OpenAI"
        case .claude: return "Claude"
        }
    }

    public var keychainKey: String {
        "VoiceFlow.\(rawValue)"
    }
}

// MARK: - CredentialError

public enum CredentialError: LocalizedError, Sendable {
    case notFound(ServiceType)
    case saveFailed(ServiceType, any Error)
    case deleteFailed(ServiceType, any Error)
    case invalidKey

    public var errorDescription: String? {
        switch self {
        case .notFound(let service):
            return "No API key found for \(service.displayName)"
        case .saveFailed(let service, let error):
            return "Failed to save \(service.displayName) key: \(error.localizedDescription)"
        case .deleteFailed(let service, let error):
            return "Failed to delete \(service.displayName) key: \(error.localizedDescription)"
        case .invalidKey:
            return "The API key is invalid"
        }
    }
}

// MARK: - CredentialClient

/// Client for secure credential storage using Keychain.
@DependencyClient
public struct CredentialClient: Sendable {
    /// Get an API key for a service.
    /// - Parameter service: The service type.
    /// - Returns: The API key if found, nil otherwise.
    public var getAPIKey: @Sendable (_ service: ServiceType) async throws -> String?

    /// Set an API key for a service.
    /// - Parameters:
    ///   - key: The API key to store.
    ///   - service: The service type.
    public var setAPIKey: @Sendable (_ key: String, _ service: ServiceType) async throws -> Void

    /// Delete an API key for a service.
    /// - Parameter service: The service type.
    public var deleteAPIKey: @Sendable (_ service: ServiceType) async throws -> Void

    /// Check if an API key exists for a service.
    /// - Parameter service: The service type.
    /// - Returns: True if a key exists.
    public var hasAPIKey: @Sendable (_ service: ServiceType) async -> Bool = { _ in false }

    /// Get all configured services.
    public var configuredServices: @Sendable () -> [ServiceType] = { [] }

    /// Validate an API key format (basic validation).
    public var validateKeyFormat: @Sendable (_ key: String, _ service: ServiceType) -> Bool = { _, _ in true }

    /// Configure credentials from environment variables.
    public var configureFromEnvironment: @Sendable () async throws -> Void = {}

    /// Perform a health check on the credential storage system.
    public var performHealthCheck: @Sendable () async -> Bool = { true }
}

// MARK: - DependencyKey

extension CredentialClient: DependencyKey {
    public static var testValue: CredentialClient {
        CredentialClient()
    }

    public static var previewValue: CredentialClient {
        CredentialClient()
    }
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var credentialClient: CredentialClient {
        get { self[CredentialClient.self] }
        set { self[CredentialClient.self] = newValue }
    }
}
