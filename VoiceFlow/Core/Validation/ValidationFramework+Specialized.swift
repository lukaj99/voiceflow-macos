import Foundation

// MARK: - Specialized Validators Extension

extension ValidationFramework {

    /// Validate API key specifically
    public func validateAPIKey(_ apiKey: String) async -> ValidationResult {
        let rule = ValidationRule(
            field: "API Key",
            required: true,
            minLength: 32,
            maxLength: 128,
            allowedCharacters: CharacterSet.alphanumerics
        )

        var result = await validate(apiKey, rule: rule)

        // Additional API key specific validation
        if result.isValid {
            // Check for common API key patterns
            if !apiKey.allSatisfy({ $0.isHexDigit || $0.isLetter || $0.isNumber }) {
                result = ValidationResult(
                    isValid: false,
                    errors: [.invalidAPIKey(field: "API Key", reason: "Contains invalid characters")]
                )
            }

            // Check for obviously fake or test keys
            let suspiciousPatterns = ["test", "fake", "demo", "example", "1234", "abcd"]
            for pattern in suspiciousPatterns where apiKey.lowercased().contains(pattern) {
                await auditLog.logSecurityThreat(
                    field: "API Key",
                    threat: .scriptInjection,
                    input: "Suspicious API key pattern"
                )
                break
            }
        }

        return result
    }

    /// Validate email address
    public func validateEmail(_ email: String) async -> ValidationResult {
        let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let rule = ValidationRule(
            field: "Email",
            required: true,
            maxLength: 254,
            pattern: emailPattern
        )

        let result = await validate(email, rule: rule)
        if !result.isValid &&
           !result.errors.contains(where: { if case .invalidFormat = $0 { return true }; return false }) {
            var errors = result.errors
            errors.append(.invalidEmail(field: "Email"))
            return ValidationResult(isValid: false, errors: errors)
        }

        return result
    }

    /// Validate URL
    public func validateURL(_ urlString: String) async -> ValidationResult {
        let rule = ValidationRule(
            field: "URL",
            required: true,
            maxLength: 2048
        )

        var result = await validate(urlString, rule: rule)

        if result.isValid {
            if URL(string: urlString) == nil {
                result = ValidationResult(
                    isValid: false,
                    errors: [.invalidURL(field: "URL")]
                )
            }
        }

        return result
    }

    /// Validate numeric range
    public func validateNumericRange(
        _ value: Double,
        field: String,
        min: Double,
        max: Double
    ) async -> ValidationResult {
        if value < min || value > max {
            await auditLog.logValidationFailure(
                field: field,
                error: "Value \(value) outside range [\(min), \(max)]"
            )
            return ValidationResult(
                isValid: false,
                errors: [.invalidRange(field: field, min: min, max: max, actual: value)]
            )
        }

        await auditLog.logValidationSuccess(field: field)
        return ValidationResult(isValid: true)
    }

    /// Batch validate multiple inputs
    public func validateBatch(_ inputs: [(String, ValidationRule)]) async -> [ValidationResult] {
        var results: [ValidationResult] = []

        for (input, rule) in inputs {
            let result = await validate(input, rule: rule)
            results.append(result)
        }

        return results
    }

    /// Get validation statistics
    public func getValidationStatistics() async -> ValidationStatistics {
        return await auditLog.getStatistics()
    }
}
