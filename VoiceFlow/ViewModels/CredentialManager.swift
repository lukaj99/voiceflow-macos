import Foundation
import Combine

/// Manages credential configuration and validation for the application
/// Single Responsibility: Credential lifecycle management and validation
@MainActor
public class CredentialManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var isConfigured = false
    @Published public var validationStatus: ValidationStatus = .unknown
    @Published public var lastValidationTime: Date?
    @Published public var healthStatus: HealthStatus = .unknown
    @Published public var configurationError: String?

    // MARK: - Types

    public enum ValidationStatus {
        case unknown
        case valid
        case invalid(String)
        case validating

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    public enum HealthStatus {
        case unknown
        case healthy
        case unhealthy(String)
        case checking

        var isHealthy: Bool {
            if case .healthy = self { return true }
            return false
        }
    }

    // MARK: - Dependencies

    private let credentialService: SecureCredentialService
    private let validationFramework: ValidationFramework
    private let appState: AppState

    // MARK: - State

    private var lastHealthCheckTime: Date?
    private let healthCheckInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    public init(
        credentialService: SecureCredentialService = SecureCredentialService(),
        validationFramework: ValidationFramework = ValidationFramework(),
        appState: AppState
    ) {
        self.credentialService = credentialService
        self.validationFramework = validationFramework
        self.appState = appState

        print("🔐 CredentialManager initialized")

        Task {
            await initializeCredentials()
        }
    }

    // MARK: - Public Interface

    /// Configure API key from user input with comprehensive validation
    public func configureAPIKey(_ apiKey: String) async {
        print("🔐 Configuring API key...")
        configurationError = nil
        validationStatus = .validating

        do {
            // Use validation framework for comprehensive validation
            try await credentialService.configureDeepgramAPIKey(from: apiKey)

            // Validate the stored key
            await validateStoredCredentials()

            if validationStatus.isValid {
                isConfigured = true
                appState.setConfigured(true)
                clearError()
                print("✅ API key configured and validated successfully")
            }

        } catch {
            validationStatus = .invalid(error.localizedDescription)
            isConfigured = false
            appState.setConfigured(false)
            setError("API key configuration failed: \(error.localizedDescription)")
            print("❌ API key configuration failed: \(error)")
        }
    }

    /// Configure credentials from environment (for development/CI)
    public func configureFromEnvironment() async {
        print("🔐 Configuring credentials from environment...")
        configurationError = nil

        do {
            try await credentialService.configureFromEnvironment()
            await validateStoredCredentials()

            if validationStatus.isValid {
                isConfigured = true
                appState.setConfigured(true)
                clearError()
                print("✅ Credentials configured from environment")
            }

        } catch {
            validationStatus = .invalid("Environment configuration failed")
            isConfigured = false
            appState.setConfigured(false)
            setError("Environment configuration failed: \(error.localizedDescription)")
            print("❌ Environment configuration failed: \(error)")
        }
    }

    /// Validate currently stored credentials
    public func validateStoredCredentials() async {
        print("🔐 Validating stored credentials...")
        validationStatus = .validating

        do {
            let hasCredentials = await credentialService.hasDeepgramAPIKey()

            guard hasCredentials else {
                validationStatus = .invalid("No API key found")
                isConfigured = false
                appState.setConfigured(false)
                return
            }

            let apiKey = try await credentialService.getDeepgramAPIKey()

            // Use validation framework for comprehensive validation
            let validationResult = await validationFramework.validateAPIKey(apiKey)

            if validationResult.isValid {
                validationStatus = .valid
                lastValidationTime = Date()
                isConfigured = true
                appState.setConfigured(true)
                clearError()
                print("✅ Stored credentials are valid")
            } else {
                let errorMessage = validationResult.errors.map(\.localizedDescription).joined(separator: "; ")
                validationStatus = .invalid(errorMessage)
                isConfigured = false
                appState.setConfigured(false)
                setError("Stored API key is invalid: \(errorMessage)")
                print("❌ Stored credentials are invalid: \(errorMessage)")
            }

        } catch {
            validationStatus = .invalid(error.localizedDescription)
            isConfigured = false
            appState.setConfigured(false)
            setError("Credential validation failed: \(error.localizedDescription)")
            print("❌ Credential validation failed: \(error)")
        }
    }

    /// Perform comprehensive health check
    public func performHealthCheck() async {
        print("🔐 Performing credential health check...")
        healthStatus = .checking

        let isHealthy = await credentialService.performHealthCheck()

        if isHealthy {
            healthStatus = .healthy
            lastHealthCheckTime = Date()

            // Also validate credentials if healthy
            await validateStoredCredentials()

            print("✅ Credential health check passed")
        } else {
            healthStatus = .unhealthy("Keychain access issue detected")
            setError("Keychain access issue. Please check app permissions.")
            print("❌ Credential health check failed")
        }
    }

    /// Remove stored credentials
    public func removeCredentials() async {
        print("🔐 Removing stored credentials...")

        do {
            try await credentialService.remove(for: .deepgramAPIKey)

            isConfigured = false
            validationStatus = .unknown
            lastValidationTime = nil
            appState.setConfigured(false)
            clearError()

            print("✅ Credentials removed successfully")

        } catch {
            setError("Failed to remove credentials: \(error.localizedDescription)")
            print("❌ Failed to remove credentials: \(error)")
        }
    }

    /// Check if automatic health check is needed
    public func checkIfHealthCheckNeeded() async {
        guard let lastCheck = lastHealthCheckTime else {
            await performHealthCheck()
            return
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        if timeSinceLastCheck > healthCheckInterval {
            await performHealthCheck()
        }
    }

    /// Get credential status summary
    public func getCredentialStatus() -> CredentialStatus {
        return CredentialStatus(
            isConfigured: isConfigured,
            validationStatus: validationStatus,
            healthStatus: healthStatus,
            lastValidationTime: lastValidationTime,
            lastHealthCheckTime: lastHealthCheckTime
        )
    }

    // MARK: - Private Methods

    /// Initialize credentials on app startup
    private func initializeCredentials() async {
        // Perform initial health check
        await performHealthCheck()

        // Only proceed if keychain is healthy
        guard healthStatus.isHealthy else {
            return
        }

        // Try to configure from environment first (for development)
        do {
            try await credentialService.configureFromEnvironment()
            print("🔐 Credentials configured from environment during initialization")
        } catch {
            print("ℹ️ No environment credentials found during initialization")
        }

        // Validate any stored credentials
        await validateStoredCredentials()

        print("🔐 Credential initialization complete: \(isConfigured ? "✅ Configured" : "⚠️ Requires user setup")")
    }

    private func setError(_ message: String) {
        configurationError = message
        appState.setError(message)
    }

    private func clearError() {
        configurationError = nil
        appState.setError(nil)
    }
}

// MARK: - Supporting Types

public struct CredentialStatus {
    public let isConfigured: Bool
    public let validationStatus: CredentialManager.ValidationStatus
    public let healthStatus: CredentialManager.HealthStatus
    public let lastValidationTime: Date?
    public let lastHealthCheckTime: Date?

    public init(
        isConfigured: Bool,
        validationStatus: CredentialManager.ValidationStatus,
        healthStatus: CredentialManager.HealthStatus,
        lastValidationTime: Date?,
        lastHealthCheckTime: Date?
    ) {
        self.isConfigured = isConfigured
        self.validationStatus = validationStatus
        self.healthStatus = healthStatus
        self.lastValidationTime = lastValidationTime
        self.lastHealthCheckTime = lastHealthCheckTime
    }

    public var isReadyForUse: Bool {
        return isConfigured && validationStatus.isValid && healthStatus.isHealthy
    }
}
