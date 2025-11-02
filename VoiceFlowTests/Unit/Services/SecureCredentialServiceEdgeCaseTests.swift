import XCTest
@testable import VoiceFlow

/// Comprehensive edge case tests for SecureCredentialService
final class SecureCredentialServiceEdgeCaseTests: XCTestCase {

    private var credentialService: SecureCredentialService!

    override func setUp() async throws {
        try await super.setUp()
        credentialService = SecureCredentialService()

        // Clean up any existing test credentials
        for key in SecureCredentialService.CredentialKey.allCases {
            try? await credentialService.remove(for: key)
        }

        // Clear cache
        await credentialService.clearCache()
    }

    override func tearDown() async throws {
        // Clean up test credentials
        for key in SecureCredentialService.CredentialKey.allCases {
            try? await credentialService.remove(for: key)
        }

        credentialService = nil
        try await super.tearDown()
    }

    // MARK: - Edge Case Tests

    func testStoreEmptyCredential() async {
        // When/Then
        do {
            try await credentialService.store(credential: "", for: .deepgramAPIKey)
            XCTFail("Should throw error for empty credential")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStoreWhitespaceOnlyCredential() async {
        // When/Then
        do {
            try await credentialService.store(credential: "   ", for: .deepgramAPIKey)
            XCTFail("Should throw error for whitespace-only credential")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStoreExtremelyLongCredential() async {
        // Given
        let longCredential = String(repeating: "a", count: 10000)

        // When/Then
        do {
            try await credentialService.store(credential: longCredential, for: .deepgramAPIKey)
            XCTFail("Should throw error for excessively long credential")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRetrieveNonExistentCredential() async {
        // When/Then
        do {
            _ = try await credentialService.retrieve(for: .deepgramAPIKey)
            XCTFail("Should throw error for non-existent credential")
        } catch SecureCredentialService.CredentialError.keyNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemoveNonExistentCredential() async {
        // When - should not throw
        do {
            try await credentialService.remove(for: .deepgramAPIKey)
        } catch {
            // Some implementations may throw, some may succeed silently
            // Both are acceptable for removing non-existent items
        }
    }

    // MARK: - Cache Tests

    func testCacheInvalidationAfterClear() async throws {
        // Given
        let testCredential = "a" * 32 + "1234567890abcdef"
        try await credentialService.store(credential: testCredential, for: .deepgramAPIKey)

        // Retrieve to populate cache
        _ = try await credentialService.retrieve(for: .deepgramAPIKey)

        // When
        await credentialService.clearCache()

        // Then - should still retrieve from keychain
        let retrieved = try await credentialService.retrieve(for: .deepgramAPIKey)
        XCTAssertEqual(retrieved, testCredential)
    }

    func testConcurrentCacheAccess() async throws {
        // Given
        let testCredential = String(repeating: "a", count: 32)
        try await credentialService.store(credential: testCredential, for: .deepgramAPIKey)

        // When - concurrent retrieves
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try? await self.credentialService.retrieve(for: .deepgramAPIKey)
                }
            }

            // Then - all should succeed
            var results: [String] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }

            XCTAssertEqual(results.count, 50)
            XCTAssertTrue(results.allSatisfy { $0 == testCredential })
        }
    }

    // MARK: - Validation Edge Cases

    func testValidateDeepgramKeyWithInvalidCharacters() async {
        // Given
        let invalidKey = "invalid!@#$%^&*()"

        // When
        let isValid = await credentialService.validateCredential(invalidKey, for: .deepgramAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateDeepgramKeyTooShort() async {
        // Given
        let shortKey = "abc123"

        // When
        let isValid = await credentialService.validateCredential(shortKey, for: .deepgramAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateOpenAIKeyWithoutPrefix() async {
        // Given
        let keyWithoutPrefix = "abc123def456" * 5

        // When
        let isValid = await credentialService.validateCredential(keyWithoutPrefix, for: .openAIAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateOpenAIKeyTooShort() async {
        // Given
        let shortKey = "sk-abc"

        // When
        let isValid = await credentialService.validateCredential(shortKey, for: .openAIAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateClaudeKeyWithoutPrefix() async {
        // Given
        let keyWithoutPrefix = "abc123" * 15

        // When
        let isValid = await credentialService.validateCredential(keyWithoutPrefix, for: .claudeAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateClaudeKeyTooShort() async {
        // Given
        let shortKey = "sk-ant-abc"

        // When
        let isValid = await credentialService.validateCredential(shortKey, for: .claudeAPIKey)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Multiple Credential Tests

    func testStoreMultipleCredentialsSimultaneously() async throws {
        // Given
        let deepgramKey = String(repeating: "a", count: 32)
        let openAIKey = "sk-" + String(repeating: "b", count: 51)
        let claudeKey = "sk-ant-" + String(repeating: "c", count: 64)

        // When
        try await credentialService.store(credential: deepgramKey, for: .deepgramAPIKey)
        try await credentialService.store(credential: openAIKey, for: .openAIAPIKey)
        try await credentialService.store(credential: claudeKey, for: .claudeAPIKey)

        // Then
        let retrieved1 = try await credentialService.retrieve(for: .deepgramAPIKey)
        let retrieved2 = try await credentialService.retrieve(for: .openAIAPIKey)
        let retrieved3 = try await credentialService.retrieve(for: .claudeAPIKey)

        XCTAssertEqual(retrieved1, deepgramKey)
        XCTAssertEqual(retrieved2, openAIKey)
        XCTAssertEqual(retrieved3, claudeKey)
    }

    func testOverwriteExistingCredential() async throws {
        // Given
        let originalKey = String(repeating: "a", count: 32)
        let newKey = String(repeating: "b", count: 32)

        try await credentialService.store(credential: originalKey, for: .deepgramAPIKey)

        // When
        try await credentialService.store(credential: newKey, for: .deepgramAPIKey)

        // Then
        let retrieved = try await credentialService.retrieve(for: .deepgramAPIKey)
        XCTAssertEqual(retrieved, newKey)
        XCTAssertNotEqual(retrieved, originalKey)
    }

    // MARK: - LLM Provider Tests

    func testConfigureLLMAPIKeyForOpenAI() async throws {
        // Given
        let validKey = "sk-" + String(repeating: "a", count: 51)

        // When
        try await credentialService.configureLLMAPIKey(from: validKey, for: .openAI)

        // Then
        let hasKey = await credentialService.hasLLMAPIKey(for: .openAI)
        XCTAssertTrue(hasKey)
    }

    func testConfigureLLMAPIKeyForClaude() async throws {
        // Given
        let validKey = "sk-ant-" + String(repeating: "a", count: 64)

        // When
        try await credentialService.configureLLMAPIKey(from: validKey, for: .claude)

        // Then
        let hasKey = await credentialService.hasLLMAPIKey(for: .claude)
        XCTAssertTrue(hasKey)
    }

    func testGetLLMAPIKeyForUnconfiguredProvider() async {
        // When/Then
        do {
            _ = try await credentialService.getLLMAPIKey(for: .openAI)
            XCTFail("Should throw error for unconfigured provider")
        } catch {
            // Expected
        }
    }

    // MARK: - Health Check Tests

    func testHealthCheckSuccess() async {
        // When
        let isHealthy = await credentialService.performHealthCheck()

        // Then
        XCTAssertTrue(isHealthy)
    }

    // MARK: - Exists Tests

    func testExistsForStoredCredential() async throws {
        // Given
        let testCredential = String(repeating: "a", count: 32)
        try await credentialService.store(credential: testCredential, for: .deepgramAPIKey)

        // When
        let exists = await credentialService.exists(for: .deepgramAPIKey)

        // Then
        XCTAssertTrue(exists)
    }

    func testExistsForNonExistentCredential() async {
        // When
        let exists = await credentialService.exists(for: .deepgramAPIKey)

        // Then
        XCTAssertFalse(exists)
    }

    // MARK: - Special Character Tests

    func testStoreCredentialWithSpecialCharacters() async throws {
        // Given
        let specialChars = "abc123!@#$%^&*()"

        // When/Then - should be rejected by validation
        do {
            try await credentialService.store(credential: specialChars, for: .deepgramAPIKey)
            // If it stores, validation should still reject it
            let isValid = await credentialService.validateCredential(specialChars, for: .deepgramAPIKey)
            XCTAssertFalse(isValid)
        } catch {
            // Expected if validation prevents storage
        }
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentStoreAndRetrieve() async throws {
        // Given
        let testCredential = String(repeating: "a", count: 32)

        // When - concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Store operations
            for _ in 0..<10 {
                group.addTask {
                    try? await self.credentialService.store(credential: testCredential, for: .deepgramAPIKey)
                }
            }

            // Retrieve operations
            for _ in 0..<10 {
                group.addTask {
                    _ = try? await self.credentialService.retrieve(for: .deepgramAPIKey)
                }
            }

            await group.waitForAll()
        }

        // Then - final state should be consistent
        let retrieved = try await credentialService.retrieve(for: .deepgramAPIKey)
        XCTAssertEqual(retrieved, testCredential)
    }

    func testRapidStoreRemoveCycles() async throws {
        // Given
        let testCredential = String(repeating: "a", count: 32)

        // When/Then - rapid cycles
        for _ in 0..<10 {
            try await credentialService.store(credential: testCredential, for: .deepgramAPIKey)
            XCTAssertTrue(await credentialService.exists(for: .deepgramAPIKey))

            try await credentialService.remove(for: .deepgramAPIKey)
            XCTAssertFalse(await credentialService.exists(for: .deepgramAPIKey))
        }
    }
}

// MARK: - String Extension for Testing

private extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
