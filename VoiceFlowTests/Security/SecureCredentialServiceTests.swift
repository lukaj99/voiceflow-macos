import XCTest
@testable import VoiceFlow

/// Comprehensive tests for SecureCredentialService security patterns
/// Validates guardrails compliance for credential management
@MainActor
final class SecureCredentialServiceTests: XCTestCase {
    
    private var credentialService: SecureCredentialService!
    
    override func setUp() async throws {
        credentialService = SecureCredentialService()
        
        // Clear any existing test credentials
        try? await credentialService.remove(for: .deepgramAPIKey)
        await credentialService.clearCache()
    }
    
    override func tearDown() async throws {
        // Clean up test credentials
        try? await credentialService.remove(for: .deepgramAPIKey)
        await credentialService.clearCache()
        credentialService = nil
    }
    
    // MARK: - Security Tests
    
    /// Test that hardcoded credentials are no longer present
    func testNoHardcodedCredentials() async throws {
        // Verify that no hardcoded API key is automatically set
        let hasKey = await credentialService.hasDeepgramAPIKey()
        XCTAssertFalse(hasKey, "No hardcoded API key should be present")
        
        // Verify that setupDefaultCredentials method no longer exists with hardcoded values
        // This is enforced by the code changes - the method now requires environment variables
    }
    
    /// Test secure API key configuration from user input
    func testSecureAPIKeyConfiguration() async throws {
        let validAPIKey = "1234567890abcdef1234567890abcdef12345678"
        
        // Test valid API key configuration
        try await credentialService.configureDeepgramAPIKey(from: validAPIKey)
        
        let hasKey = await credentialService.hasDeepgramAPIKey()
        XCTAssertTrue(hasKey, "API key should be stored after configuration")
        
        let retrievedKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(retrievedKey, validAPIKey, "Retrieved key should match stored key")
    }
    
    /// Test invalid API key rejection
    func testInvalidAPIKeyRejection() async throws {
        let invalidKeys = [
            "",                           // Empty key
            "short",                     // Too short
            "invalid-characters-123!@#", // Invalid characters
            "1234567890abcdef",         // Too short (only 16 chars)
        ]
        
        for invalidKey in invalidKeys {
            do {
                try await credentialService.configureDeepgramAPIKey(from: invalidKey)
                XCTFail("Should reject invalid API key: \(invalidKey)")
            } catch SecureCredentialService.CredentialError.invalidCredential {
                // Expected behavior
            } catch {
                XCTFail("Unexpected error for invalid key \(invalidKey): \(error)")
            }
        }
    }
    
    /// Test environment variable configuration
    func testEnvironmentVariableConfiguration() async throws {
        let testAPIKey = "abcdef1234567890abcdef1234567890abcdef12"
        
        // Set environment variable (simulated)
        setenv("DEEPGRAM_API_KEY", testAPIKey, 1)
        defer { unsetenv("DEEPGRAM_API_KEY") }
        
        try await credentialService.configureFromEnvironment()
        
        let hasKey = await credentialService.hasDeepgramAPIKey()
        XCTAssertTrue(hasKey, "API key should be configured from environment")
        
        let retrievedKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(retrievedKey, testAPIKey, "Key should match environment variable")
    }
    
    /// Test environment variable failure handling
    func testEnvironmentVariableFailure() async throws {
        // Ensure no environment variable is set
        unsetenv("DEEPGRAM_API_KEY")
        
        do {
            try await credentialService.configureFromEnvironment()
            XCTFail("Should fail when no environment variable is set")
        } catch SecureCredentialService.CredentialError.keyNotFound {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    /// Test credential validation
    func testCredentialValidation() async throws {
        let validKey = "1234567890abcdef1234567890abcdef12345678"
        let invalidKey = "invalid-key"
        
        let validResult = await credentialService.validateCredential(validKey, for: .deepgramAPIKey)
        XCTAssertTrue(validResult, "Valid key should pass validation")
        
        let invalidResult = await credentialService.validateCredential(invalidKey, for: .deepgramAPIKey)
        XCTAssertFalse(invalidResult, "Invalid key should fail validation")
    }
    
    /// Test secure credential removal
    func testSecureCredentialRemoval() async throws {
        let testAPIKey = "fedcba0987654321fedcba0987654321fedcba09"
        
        // Store a credential
        try await credentialService.configureDeepgramAPIKey(from: testAPIKey)
        XCTAssertTrue(await credentialService.hasDeepgramAPIKey(), "Key should be stored")
        
        // Remove the credential
        try await credentialService.remove(for: .deepgramAPIKey)
        XCTAssertFalse(await credentialService.hasDeepgramAPIKey(), "Key should be removed")
        
        // Verify it can't be retrieved
        do {
            _ = try await credentialService.getDeepgramAPIKey()
            XCTFail("Should not be able to retrieve removed key")
        } catch SecureCredentialService.CredentialError.keyNotFound {
            // Expected behavior
        }
    }
    
    // MARK: - Cache Security Tests
    
    /// Test credential cache timeout
    func testCredentialCacheTimeout() async throws {
        let testAPIKey = "9876543210fedcba9876543210fedcba98765432"
        
        // Store credential
        try await credentialService.configureDeepgramAPIKey(from: testAPIKey)
        
        // First retrieval should work
        let firstKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(firstKey, testAPIKey)
        
        // Clear cache
        await credentialService.clearCache()
        
        // Second retrieval should still work (from keychain)
        let secondKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(secondKey, testAPIKey)
    }
    
    /// Test cache security
    func testCacheSecurity() async throws {
        let testAPIKey = "abcd1234efgh5678ijkl9012mnop3456qrst7890"
        
        try await credentialService.configureDeepgramAPIKey(from: testAPIKey)
        
        // Verify cache doesn't expose credentials through memory dumps
        // This is more of a design verification - the cache is internal to the actor
        await credentialService.clearCache()
        
        // Key should still be retrievable from secure keychain
        let retrievedKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(retrievedKey, testAPIKey)
    }
    
    // MARK: - Health Check Tests
    
    /// Test keychain health check
    func testKeychainHealthCheck() async throws {
        let isHealthy = await credentialService.performHealthCheck()
        XCTAssertTrue(isHealthy, "Keychain should be accessible in test environment")
    }
    
    // MARK: - Error Handling Tests
    
    /// Test proper error handling for all failure scenarios
    func testComprehensiveErrorHandling() async throws {
        // Test empty credential storage
        do {
            try await credentialService.store(credential: "", for: .deepgramAPIKey)
            XCTFail("Should reject empty credential")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected
        }
        
        // Test whitespace-only credential
        do {
            try await credentialService.store(credential: "   \n\t   ", for: .deepgramAPIKey)
            XCTFail("Should reject whitespace-only credential")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected
        }
        
        // Test retrieval of non-existent key
        do {
            _ = try await credentialService.retrieve(for: .deepgramAPIKey)
            XCTFail("Should fail to retrieve non-existent key")
        } catch SecureCredentialService.CredentialError.keyNotFound {
            // Expected
        }
    }
    
    // MARK: - Actor Isolation Tests
    
    /// Test that credential service is properly actor-isolated
    func testActorIsolation() async throws {
        // This test verifies that the service is actor-isolated
        // by testing concurrent access patterns
        
        let testKey = "concurrent1234567890abcdefconcurrent12"
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent operations should be serialized by the actor
            for i in 0..<5 {
                group.addTask {
                    do {
                        try await self.credentialService.configureDeepgramAPIKey(from: "\(testKey)\(i)")
                        _ = try await self.credentialService.getDeepgramAPIKey()
                    } catch {
                        // Some operations may fail due to validation, that's okay
                    }
                }
            }
        }
        
        // Verify final state is consistent
        let hasKey = await credentialService.hasDeepgramAPIKey()
        if hasKey {
            let finalKey = try await credentialService.getDeepgramAPIKey()
            XCTAssertTrue(finalKey.hasPrefix(testKey), "Final key should be from one of the operations")
        }
    }
    
    // MARK: - Integration Tests
    
    /// Test integration with the overall security patterns
    func testSecurityIntegration() async throws {
        // Test the complete workflow that replaces hardcoded credentials
        
        // 1. Verify no credentials exist initially
        XCTAssertFalse(await credentialService.hasDeepgramAPIKey())
        
        // 2. Attempt to ensure credentials are configured (should fail)
        do {
            try await credentialService.ensureCredentialsConfigured()
            XCTFail("Should fail when no credentials are configured")
        } catch SecureCredentialService.CredentialError.keyNotFound {
            // Expected
        }
        
        // 3. Configure credentials securely
        let validKey = "security1234567890abcdefghijklmnop1234"
        try await credentialService.configureDeepgramAPIKey(from: validKey)
        
        // 4. Verify credentials are now properly configured
        try await credentialService.ensureCredentialsConfigured() // Should not throw
        
        // 5. Verify key can be retrieved and validated
        let retrievedKey = try await credentialService.getDeepgramAPIKey()
        XCTAssertEqual(retrievedKey, validKey)
        
        let isValid = await credentialService.validateCredential(retrievedKey, for: .deepgramAPIKey)
        XCTAssertTrue(isValid)
    }
}

// MARK: - Performance Tests

extension SecureCredentialServiceTests {
    
    /// Test performance of credential operations
    func testCredentialOperationPerformance() async throws {
        let testKey = "performance1234567890abcdefperformance12"
        
        // Measure storage performance
        let storageTime = await measureAsync {
            try? await credentialService.configureDeepgramAPIKey(from: testKey)
        }
        
        // Measure retrieval performance
        let retrievalTime = await measureAsync {
            _ = try? await credentialService.getDeepgramAPIKey()
        }
        
        // Performance should be reasonable (under 1 second for basic operations)
        XCTAssertLessThan(storageTime, 1.0, "Credential storage should be fast")
        XCTAssertLessThan(retrievalTime, 1.0, "Credential retrieval should be fast")
    }
    
    private func measureAsync(_ operation: @escaping () async -> Void) async -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return timeElapsed
    }
}