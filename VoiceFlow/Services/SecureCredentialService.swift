import Foundation
import KeychainAccess

/// Actor-isolated service for secure credential management using keychain storage
/// Follows Swift 6 concurrency best practices and 2025 security standards
public actor SecureCredentialService {
    
    // MARK: - Types
    
    public enum CredentialError: LocalizedError, Sendable {
        case keyNotFound(String)
        case storageFailure(String)
        case invalidCredential(String)
        case keychainAccessDenied
        
        public var errorDescription: String? {
            switch self {
            case .keyNotFound(let key):
                return "Credential not found: \(key)"
            case .storageFailure(let reason):
                return "Failed to store credential: \(reason)"
            case .invalidCredential(let key):
                return "Invalid credential format: \(key)"
            case .keychainAccessDenied:
                return "Keychain access denied. Please check app permissions."
            }
        }
    }
    
    public enum CredentialKey: String, CaseIterable, Sendable {
        case deepgramAPIKey = "deepgram_api_key"
        case userPreferences = "user_preferences"
        case sessionTokens = "session_tokens"
        
        var serviceName: String {
            "com.voiceflow.credentials"
        }
        
        var accessGroup: String? {
            // Use app group for sharing between app components if needed
            Bundle.main.object(forInfoDictionaryKey: "VoiceFlowAccessGroup") as? String
        }
    }
    
    // MARK: - Properties
    
    private let keychain: Keychain
    private var cachedCredentials: [CredentialKey: String] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [CredentialKey: Date] = [:]
    private let validator = ValidationFramework()
    
    // MARK: - Initialization
    
    public init() {
        // Initialize keychain with service identifier and accessibility settings
        self.keychain = Keychain(service: CredentialKey.deepgramAPIKey.serviceName)
            .accessibility(.whenUnlockedThisDeviceOnly) // More secure: requires device unlock
            .synchronizable(false) // Keep credentials local for security
        
        print("🔐 SecureCredentialService initialized with secure keychain access")
    }
    
    // MARK: - Public Interface
    
    /// Store a credential securely in the keychain with validation
    public func store(credential: String, for key: CredentialKey) async throws {
        // Use validation framework for comprehensive input validation
        let validationRule = ValidationFramework.ValidationRule(
            field: key.rawValue,
            required: true,
            minLength: 1,
            maxLength: 1000
        )
        
        let validationResult = await validator.validate(credential, rule: validationRule)
        
        guard validationResult.isValid else {
            let errorMessage = validationResult.errors.first?.localizedDescription ?? "Invalid credential format"
            throw CredentialError.invalidCredential("\(key.rawValue): \(errorMessage)")
        }
        
        // Use sanitized input
        let sanitizedCredential = validationResult.sanitized ?? credential
        
        do {
            try keychain.set(sanitizedCredential, key: key.rawValue)
            
            // Update cache with sanitized credential
            cachedCredentials[key] = sanitizedCredential
            cacheTimestamps[key] = Date()
            
            print("🔐 Stored validated credential for key: \(key.rawValue)")
            
        } catch {
            print("❌ Failed to store credential for \(key.rawValue): \(error)")
            throw CredentialError.storageFailure(error.localizedDescription)
        }
    }
    
    /// Retrieve a credential from secure storage
    public func retrieve(for key: CredentialKey) async throws -> String {
        // Check cache first (with timeout)
        if let cached = cachedCredentials[key],
           let timestamp = cacheTimestamps[key],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cached
        }
        
        do {
            guard let credential = try keychain.get(key.rawValue) else {
                throw CredentialError.keyNotFound(key.rawValue)
            }
            
            // Update cache
            cachedCredentials[key] = credential
            cacheTimestamps[key] = Date()
            
            print("🔐 Retrieved credential for key: \(key.rawValue)")
            return credential
            
        } catch let error as CredentialError {
            throw error
        } catch {
            print("❌ Failed to retrieve credential for \(key.rawValue): \(error)")
            throw CredentialError.keychainAccessDenied
        }
    }
    
    /// Check if a credential exists without retrieving it
    public func exists(for key: CredentialKey) async -> Bool {
        do {
            let _ = try await retrieve(for: key)
            return true
        } catch {
            return false
        }
    }
    
    /// Remove a credential from secure storage
    public func remove(for key: CredentialKey) async throws {
        do {
            try keychain.remove(key.rawValue)
            
            // Clear from cache
            cachedCredentials.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
            
            print("🔐 Removed credential for key: \(key.rawValue)")
            
        } catch {
            print("❌ Failed to remove credential for \(key.rawValue): \(error)")
            throw CredentialError.storageFailure(error.localizedDescription)
        }
    }
    
    /// Clear all cached credentials (forces fresh keychain reads)
    public func clearCache() async {
        cachedCredentials.removeAll()
        cacheTimestamps.removeAll()
        print("🔐 Credential cache cleared")
    }
    
    /// Validate credential format (basic validation)
    public func validateCredential(_ credential: String, for key: CredentialKey) async -> Bool {
        switch key {
        case .deepgramAPIKey:
            // Deepgram API keys are typically 32+ character hex strings
            return credential.count >= 32 && credential.allSatisfy { $0.isHexDigit }
        case .userPreferences, .sessionTokens:
            // Basic non-empty validation for other types
            return !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Store Deepgram API key with validation
    public func storeDeepgramAPIKey(_ apiKey: String) async throws {
        guard await validateCredential(apiKey, for: .deepgramAPIKey) else {
            throw CredentialError.invalidCredential("Deepgram API key format invalid")
        }
        
        try await store(credential: apiKey, for: .deepgramAPIKey)
        print("✅ Deepgram API key stored successfully")
    }
    
    /// Retrieve Deepgram API key
    public func getDeepgramAPIKey() async throws -> String {
        return try await retrieve(for: .deepgramAPIKey)
    }
    
    /// Check if Deepgram API key is configured
    public func hasDeepgramAPIKey() async -> Bool {
        return await exists(for: .deepgramAPIKey)
    }
    
    // MARK: - Migration & Setup
    
    /// Prompt user to configure API key if none exists (secure approach)
    public func ensureCredentialsConfigured() async throws {
        if !(await hasDeepgramAPIKey()) {
            throw CredentialError.keyNotFound("Deepgram API key not configured. Please configure your API key through the settings.")
        }
    }
    
    /// Validate and configure API key from user input with comprehensive validation
    public func configureDeepgramAPIKey(from userInput: String) async throws {
        // Use validation framework for comprehensive API key validation
        let validationResult = await validator.validateAPIKey(userInput)
        
        guard validationResult.isValid else {
            let errorMessage = validationResult.errors.map(\.localizedDescription).joined(separator: "; ")
            throw CredentialError.invalidCredential("Deepgram API key validation failed: \(errorMessage)")
        }
        
        // Use sanitized API key
        let sanitizedKey = validationResult.sanitized ?? userInput
        
        // Store the validated and sanitized API key
        try await storeDeepgramAPIKey(sanitizedKey)
        print("✅ Deepgram API key validated and configured successfully from user input")
    }
    
    /// Import API key from environment variable (for development/CI)
    public func configureFromEnvironment() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            throw CredentialError.keyNotFound("DEEPGRAM_API_KEY environment variable not found")
        }
        
        guard !apiKey.isEmpty else {
            throw CredentialError.invalidCredential("DEEPGRAM_API_KEY environment variable is empty")
        }
        
        try await configureDeepgramAPIKey(from: apiKey)
        print("✅ Deepgram API key configured from environment variable")
    }
    
    /// Health check for keychain accessibility
    public func performHealthCheck() async -> Bool {
        do {
            // Test by storing and retrieving a test value
            let testKey = "health_check_\(UUID().uuidString)"
            let testValue = "test_value"
            
            try keychain.set(testValue, key: testKey)
            let retrieved = try keychain.get(testKey)
            try keychain.remove(testKey)
            
            let isHealthy = retrieved == testValue
            print("🔐 Keychain health check: \(isHealthy ? "✅ Passed" : "❌ Failed")")
            return isHealthy
            
        } catch {
            print("❌ Keychain health check failed: \(error)")
            return false
        }
    }
}

// MARK: - Extensions

extension Character {
    fileprivate var isHexDigit: Bool {
        return self.isASCII && (self.isNumber || ("a"..."f").contains(self.lowercased().first!))
    }
}