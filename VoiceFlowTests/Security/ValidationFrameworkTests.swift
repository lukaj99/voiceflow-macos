import XCTest
@testable import VoiceFlow

/// Comprehensive tests for ValidationFramework security and functionality
/// Validates all input validation patterns and security threat detection
final class ValidationFrameworkTests: XCTestCase {
    
    private var validator: ValidationFramework!
    
    override func setUp() async throws {
        validator = ValidationFramework()
        
        // Allow initialization to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        validator = nil
    }
    
    // MARK: - Basic Validation Tests
    
    /// Test basic string validation with length requirements
    func testBasicValidation() async throws {
        let rule = ValidationFramework.ValidationRule(
            field: "Test Field",
            required: true,
            minLength: 5,
            maxLength: 20
        )
        
        // Valid input
        let validResult = await validator.validate("ValidInput", rule: rule)
        XCTAssertTrue(validResult.isValid, "Valid input should pass validation")
        XCTAssertTrue(validResult.errors.isEmpty, "Valid input should have no errors")
        XCTAssertNotNil(validResult.sanitized, "Valid input should have sanitized output")
        
        // Too short
        let shortResult = await validator.validate("Hi", rule: rule)
        XCTAssertFalse(shortResult.isValid, "Short input should fail validation")
        XCTAssertTrue(shortResult.errors.contains { 
            if case .tooShort = $0 { return true }
            return false
        }, "Should contain too short error")
        
        // Too long
        let longInput = String(repeating: "a", count: 25)
        let longResult = await validator.validate(longInput, rule: rule)
        XCTAssertFalse(longResult.isValid, "Long input should fail validation")
        XCTAssertTrue(longResult.errors.contains { 
            if case .tooLong = $0 { return true }
            return false
        }, "Should contain too long error")
        
        // Empty required field
        let emptyResult = await validator.validate("", rule: rule)
        XCTAssertFalse(emptyResult.isValid, "Empty required field should fail validation")
        XCTAssertTrue(emptyResult.errors.contains { 
            if case .empty = $0 { return true }
            return false
        }, "Should contain empty field error")
    }
    
    // MARK: - API Key Validation Tests
    
    /// Test API key validation with various formats
    func testAPIKeyValidation() async throws {
        // Valid API keys
        let validKeys = [
            "1234567890abcdef1234567890abcdef", // 32 chars hex
            "abcdef1234567890abcdef1234567890abcdef12", // 40 chars hex
            "0123456789abcdef0123456789abcdef01234567890abcdef" // 48 chars hex
        ]
        
        for key in validKeys {
            let result = await validator.validateAPIKey(key)
            XCTAssertTrue(result.isValid, "Valid API key should pass: \(key)")
            XCTAssertTrue(result.errors.isEmpty, "Valid API key should have no errors")
        }
        
        // Invalid API keys
        let invalidKeys = [
            "", // Empty
            "short", // Too short
            "1234567890abcdef1234567890abcdef!", // Invalid character
            "not-hex-characters-here-12345678", // Non-hex characters
            String(repeating: "a", count: 200) // Too long
        ]
        
        for key in invalidKeys {
            let result = await validator.validateAPIKey(key)
            XCTAssertFalse(result.isValid, "Invalid API key should fail: \(key)")
            XCTAssertFalse(result.errors.isEmpty, "Invalid API key should have errors")
        }
    }
    
    // MARK: - Security Threat Detection Tests
    
    /// Test detection of various security threats
    func testSecurityThreatDetection() async throws {
        let maliciousInputs = [
            // SQL Injection attempts
            "'; DROP TABLE users; --",
            "UNION SELECT password FROM users",
            "INSERT INTO users VALUES",
            
            // XSS attempts
            "<script>alert('xss')</script>",
            "javascript:alert('test')",
            "<iframe src=\"evil.com\"></iframe>",
            "onload=\"alert('xss')\"",
            
            // Command injection
            "; rm -rf /",
            "| cat /etc/passwd",
            "&& shutdown -h now",
            "$(cat /etc/passwd)",
            
            // Path traversal
            "../../../etc/passwd",
            "..\\..\\windows\\system32",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            
            // Script injection
            "eval(alert('test'))",
            "function(){alert('test')}",
            "${eval(alert('test'))}",
            
            // HTML injection
            "<html><body>malicious</body></html>",
            "&lt;script&gt;alert('test')&lt;/script&gt;",
            "&#x3C;script&#x3E;alert('test')&#x3C;/script&#x3E;"
        ]
        
        let rule = ValidationFramework.ValidationRule(
            field: "User Input",
            required: false,
            maxLength: 1000
        )
        
        for maliciousInput in maliciousInputs {
            let result = await validator.validate(maliciousInput, rule: rule)
            XCTAssertFalse(result.isValid, "Malicious input should be detected: \(maliciousInput.prefix(30))...")
            
            let hasSecurityThreat = result.errors.contains { error in
                if case .potentialSecurityThreat = error {
                    return true
                }
                return false
            }
            XCTAssertTrue(hasSecurityThreat, "Should detect security threat in: \(maliciousInput.prefix(30))...")
        }
    }
    
    /// Test that legitimate content is not flagged as malicious
    func testLegitimateContentNotFlagged() async throws {
        let legitimateInputs = [
            "Hello, this is a normal message",
            "My email is user@example.com",
            "The price is $19.99",
            "Visit https://example.com for more info",
            "Script writing tips for beginners",
            "How to select the best option",
            "File path: /home/user/documents",
            "Special characters: !@#$%^&*()",
            "Mathematical expression: f(x) = x + 1",
            "HTML entities: &amp; &lt; &gt;"
        ]
        
        let rule = ValidationFramework.ValidationRule(
            field: "User Input",
            required: false,
            maxLength: 1000
        )
        
        for legitimateInput in legitimateInputs {
            let result = await validator.validate(legitimateInput, rule: rule)
            
            // Check if any security threats were detected
            let hasSecurityThreat = result.errors.contains { error in
                if case .potentialSecurityThreat = error {
                    return true
                }
                return false
            }
            
            XCTAssertFalse(hasSecurityThreat, "Legitimate content should not be flagged: \(legitimateInput)")
        }
    }
    
    // MARK: - Character Set Validation Tests
    
    /// Test character set restrictions
    func testCharacterSetValidation() async throws {
        let alphanumericRule = ValidationFramework.ValidationRule(
            field: "Alphanumeric Field",
            required: true,
            allowedCharacters: .alphanumerics
        )
        
        // Valid alphanumeric
        let validResult = await validator.validate("abc123XYZ", rule: alphanumericRule)
        XCTAssertTrue(validResult.isValid, "Alphanumeric input should be valid")
        
        // Invalid characters
        let invalidResult = await validator.validate("abc@123#xyz", rule: alphanumericRule)
        XCTAssertFalse(invalidResult.isValid, "Input with special characters should be invalid")
        XCTAssertTrue(invalidResult.errors.contains { 
            if case .containsIllegalCharacters = $0 { return true }
            return false
        }, "Should contain illegal characters error")
    }
    
    // MARK: - Pattern Validation Tests
    
    /// Test regex pattern validation
    func testPatternValidation() async throws {
        // Email pattern validation
        let emailRule = ValidationFramework.ValidationRule(
            field: "Email",
            required: true,
            pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        )
        
        // Valid emails
        let validEmails = [
            "user@example.com",
            "test.email+tag@domain.co.uk",
            "user123@test-domain.org"
        ]
        
        for email in validEmails {
            let result = await validator.validate(email, rule: emailRule)
            XCTAssertTrue(result.isValid, "Valid email should pass: \(email)")
        }
        
        // Invalid emails
        let invalidEmails = [
            "not-an-email",
            "@domain.com",
            "user@",
            "user space@domain.com"
        ]
        
        for email in invalidEmails {
            let result = await validator.validate(email, rule: emailRule)
            XCTAssertFalse(result.isValid, "Invalid email should fail: \(email)")
        }
    }
    
    // MARK: - Email Validation Tests
    
    /// Test dedicated email validation method
    func testEmailValidation() async throws {
        // Valid emails
        let validEmails = [
            "user@example.com",
            "test.email@domain.org",
            "user+tag@example.co.uk"
        ]
        
        for email in validEmails {
            let result = await validator.validateEmail(email)
            XCTAssertTrue(result.isValid, "Valid email should pass: \(email)")
        }
        
        // Invalid emails
        let invalidEmails = [
            "",
            "invalid-email",
            "@domain.com",
            "user@",
            "user@domain",
            "user space@domain.com"
        ]
        
        for email in invalidEmails {
            let result = await validator.validateEmail(email)
            XCTAssertFalse(result.isValid, "Invalid email should fail: \(email)")
        }
    }
    
    // MARK: - URL Validation Tests
    
    /// Test URL validation
    func testURLValidation() async throws {
        // Valid URLs
        let validURLs = [
            "https://example.com",
            "http://test.org/path",
            "https://subdomain.example.com/path?query=value"
        ]
        
        for url in validURLs {
            let result = await validator.validateURL(url)
            XCTAssertTrue(result.isValid, "Valid URL should pass: \(url)")
        }
        
        // Invalid URLs
        let invalidURLs = [
            "",
            "not-a-url",
            "ftp://",
            "http://",
            "malformed url with spaces"
        ]
        
        for url in invalidURLs {
            let result = await validator.validateURL(url)
            XCTAssertFalse(result.isValid, "Invalid URL should fail: \(url)")
        }
    }
    
    // MARK: - Numeric Range Validation Tests
    
    /// Test numeric range validation
    func testNumericRangeValidation() async throws {
        // Valid range
        let validResult = await validator.validateNumericRange(5.0, field: "Test Value", min: 1.0, max: 10.0)
        XCTAssertTrue(validResult.isValid, "Value within range should be valid")
        
        // Too low
        let lowResult = await validator.validateNumericRange(0.5, field: "Test Value", min: 1.0, max: 10.0)
        XCTAssertFalse(lowResult.isValid, "Value below range should be invalid")
        
        // Too high
        let highResult = await validator.validateNumericRange(15.0, field: "Test Value", min: 1.0, max: 10.0)
        XCTAssertFalse(highResult.isValid, "Value above range should be invalid")
    }
    
    // MARK: - Batch Validation Tests
    
    /// Test batch validation functionality
    func testBatchValidation() async throws {
        let inputs: [(String, ValidationFramework.ValidationRule)] = [
            ("ValidInput1", ValidationFramework.commonRules.userName),
            ("valid@email.com", ValidationFramework.ValidationRule(field: "Email", pattern: "^[^@]+@[^@]+\\.[^@]+$")),
            ("1234567890abcdef1234567890abcdef", ValidationFramework.commonRules.apiKey)
        ]
        
        let results = await validator.validateBatch(inputs)
        
        XCTAssertEqual(results.count, 3, "Should return result for each input")
        XCTAssertTrue(results.allSatisfy(\.isValid), "All valid inputs should pass")
        
        // Test with some invalid inputs
        let mixedInputs: [(String, ValidationFramework.ValidationRule)] = [
            ("ValidInput", ValidationFramework.commonRules.userName),
            ("invalid-email", ValidationFramework.ValidationRule(field: "Email", pattern: "^[^@]+@[^@]+\\.[^@]+$")),
            ("short", ValidationFramework.commonRules.apiKey)
        ]
        
        let mixedResults = await validator.validateBatch(mixedInputs)
        XCTAssertEqual(mixedResults.count, 3, "Should return result for each input")
        XCTAssertTrue(mixedResults[0].isValid, "Valid input should pass")
        XCTAssertFalse(mixedResults[1].isValid, "Invalid email should fail")
        XCTAssertFalse(mixedResults[2].isValid, "Short API key should fail")
    }
    
    // MARK: - Statistics and Monitoring Tests
    
    /// Test validation statistics collection
    func testValidationStatistics() async throws {
        // Perform some validations
        _ = await validator.validateAPIKey("1234567890abcdef1234567890abcdef")
        _ = await validator.validateAPIKey("invalid")
        _ = await validator.validateEmail("valid@email.com")
        _ = await validator.validateEmail("invalid-email")
        
        let stats = await validator.getValidationStatistics()
        
        XCTAssertGreaterThan(stats.totalAttempts, 0, "Should have recorded validation attempts")
        XCTAssertGreaterThan(stats.successCount, 0, "Should have recorded successes")
        XCTAssertGreaterThan(stats.failureCount, 0, "Should have recorded failures")
        XCTAssertGreaterThan(stats.successRate, 0.0, "Should have calculated success rate")
        XCTAssertLessThan(stats.successRate, 1.0, "Success rate should be less than 1.0")
    }
    
    // MARK: - Sanitization Tests
    
    /// Test input sanitization
    func testInputSanitization() async throws {
        let rule = ValidationFramework.ValidationRule(
            field: "Test Input",
            required: true,
            minLength: 1,
            maxLength: 100
        )
        
        // Input with control characters and null bytes
        let dirtyInput = "Clean text\0\u{0001}\u{0002} more clean text\t\n"
        let result = await validator.validate(dirtyInput, rule: rule)
        
        XCTAssertTrue(result.isValid, "Input should be valid after sanitization")
        XCTAssertNotNil(result.sanitized, "Should provide sanitized output")
        
        let sanitized = result.sanitized!
        XCTAssertFalse(sanitized.contains("\0"), "Should remove null bytes")
        XCTAssertFalse(sanitized.contains("\u{0001}"), "Should remove control characters")
        XCTAssertTrue(sanitized.contains("\t"), "Should preserve tabs")
        XCTAssertTrue(sanitized.contains("\n"), "Should preserve newlines")
        XCTAssertTrue(sanitized.contains("Clean text"), "Should preserve normal text")
    }
    
    // MARK: - Common Rules Tests
    
    /// Test predefined common validation rules
    func testCommonRules() async throws {
        // Test user name rule
        let validUserName = await validator.validate("John_Doe", rule: ValidationFramework.commonRules.userName)
        XCTAssertTrue(validUserName.isValid, "Valid user name should pass")
        
        let invalidUserName = await validator.validate("J", rule: ValidationFramework.commonRules.userName)
        XCTAssertFalse(invalidUserName.isValid, "Too short user name should fail")
        
        // Test file name rule
        let validFileName = await validator.validate("document.pdf", rule: ValidationFramework.commonRules.fileName)
        XCTAssertTrue(validFileName.isValid, "Valid file name should pass")
        
        let invalidFileName = await validator.validate("file|with|pipes", rule: ValidationFramework.commonRules.fileName)
        XCTAssertFalse(invalidFileName.isValid, "File name with illegal characters should fail")
        
        // Test transcription text rule
        let validTranscription = await validator.validate("This is transcribed text.", rule: ValidationFramework.commonRules.transcriptionText)
        XCTAssertTrue(validTranscription.isValid, "Valid transcription should pass")
        
        // Test settings value rule
        let validSetting = await validator.validate("enabled", rule: ValidationFramework.commonRules.settingsValue)
        XCTAssertTrue(validSetting.isValid, "Valid setting should pass")
    }
    
    // MARK: - Performance Tests
    
    /// Test validation performance with large inputs
    func testValidationPerformance() async throws {
        let largeInput = String(repeating: "a", count: 10000)
        let rule = ValidationFramework.ValidationRule(
            field: "Large Input",
            required: true,
            maxLength: 20000
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await validator.validate(largeInput, rule: rule)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertTrue(result.isValid, "Large valid input should pass")
        XCTAssertLessThan(timeElapsed, 1.0, "Validation should complete quickly (under 1 second)")
    }
    
    // MARK: - Concurrent Validation Tests
    
    /// Test concurrent validation operations
    func testConcurrentValidation() async throws {
        let inputs = (1...100).map { "test_input_\($0)" }
        let rule = ValidationFramework.commonRules.userName
        
        await withTaskGroup(of: ValidationFramework.ValidationResult.self) { group in
            for input in inputs {
                group.addTask {
                    return await self.validator.validate(input, rule: rule)
                }
            }
            
            var results: [ValidationFramework.ValidationResult] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, 100, "Should handle concurrent validations")
            XCTAssertTrue(results.allSatisfy(\.isValid), "All concurrent validations should succeed")
        }
    }
}

// MARK: - Integration Tests

extension ValidationFrameworkTests {
    
    /// Test integration with SecureCredentialService
    func testSecureCredentialServiceIntegration() async throws {
        let credentialService = SecureCredentialService()
        
        // Test storing valid API key with validation
        let validKey = "1234567890abcdef1234567890abcdef"
        
        do {
            try await credentialService.configureDeepgramAPIKey(from: validKey)
            
            let hasKey = await credentialService.hasDeepgramAPIKey()
            XCTAssertTrue(hasKey, "Valid API key should be stored successfully")
            
            // Clean up
            try await credentialService.remove(for: .deepgramAPIKey)
        } catch {
            XCTFail("Valid API key should not cause errors: \(error)")
        }
        
        // Test storing invalid API key
        let invalidKey = "invalid-key"
        
        do {
            try await credentialService.configureDeepgramAPIKey(from: invalidKey)
            XCTFail("Invalid API key should be rejected")
        } catch SecureCredentialService.CredentialError.invalidCredential {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}