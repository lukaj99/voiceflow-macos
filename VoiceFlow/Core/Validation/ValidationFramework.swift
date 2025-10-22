import Foundation
import SwiftUI

/// Comprehensive input validation framework for VoiceFlow
/// Provides secure, type-safe input validation with detailed error reporting
public actor ValidationFramework {
    
    // MARK: - Types
    
    /// Validation result with detailed error information
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let sanitized: String?
        
        public init(isValid: Bool, errors: [ValidationError] = [], sanitized: String? = nil) {
            self.isValid = isValid
            self.errors = errors
            self.sanitized = sanitized
        }
    }
    
    /// Comprehensive validation error types
    public enum ValidationError: Error, LocalizedError, Sendable {
        case empty(field: String)
        case tooShort(field: String, minimum: Int, actual: Int)
        case tooLong(field: String, maximum: Int, actual: Int)
        case invalidFormat(field: String, expected: String)
        case containsIllegalCharacters(field: String, characters: [Character])
        case potentialSecurityThreat(field: String, threat: SecurityThreat)
        case invalidRange(field: String, min: Double, max: Double, actual: Double)
        case invalidEmail(field: String)
        case invalidURL(field: String)
        case invalidAPIKey(field: String, reason: String)
        case custom(field: String, message: String)
        
        public var errorDescription: String? {
            switch self {
            case .empty(let field):
                return "\(field) cannot be empty"
            case .tooShort(let field, let minimum, let actual):
                return "\(field) must be at least \(minimum) characters (got \(actual))"
            case .tooLong(let field, let maximum, let actual):
                return "\(field) must be no more than \(maximum) characters (got \(actual))"
            case .invalidFormat(let field, let expected):
                return "\(field) format is invalid. Expected: \(expected)"
            case .containsIllegalCharacters(let field, let characters):
                return "\(field) contains illegal characters: \(characters.map(String.init).joined(separator: ", "))"
            case .potentialSecurityThreat(let field, let threat):
                return "\(field) contains potential security threat: \(threat.description)"
            case .invalidRange(let field, let min, let max, let actual):
                return "\(field) must be between \(min) and \(max) (got \(actual))"
            case .invalidEmail(let field):
                return "\(field) must be a valid email address"
            case .invalidURL(let field):
                return "\(field) must be a valid URL"
            case .invalidAPIKey(let field, let reason):
                return "\(field) is not a valid API key: \(reason)"
            case .custom(let field, let message):
                return "\(field): \(message)"
            }
        }
    }
    
    /// Security threat detection
    public enum SecurityThreat: String, CaseIterable, Sendable {
        case sqlInjection = "SQL injection attempt"
        case xssAttempt = "Cross-site scripting attempt"
        case commandInjection = "Command injection attempt"
        case pathTraversal = "Path traversal attempt"
        case scriptInjection = "Script injection attempt"
        case htmlInjection = "HTML injection attempt"
        
        var description: String { rawValue }
    }
    
    /// Validation rule configuration
    public struct ValidationRule: Sendable {
        public let field: String
        public let required: Bool
        public let minLength: Int?
        public let maxLength: Int?
        public let pattern: String?
        public let allowedCharacters: CharacterSet?
        public let customValidator: (@Sendable (String) async -> Bool)?
        
        public init(
            field: String,
            required: Bool = true,
            minLength: Int? = nil,
            maxLength: Int? = nil,
            pattern: String? = nil,
            allowedCharacters: CharacterSet? = nil,
            customValidator: (@Sendable (String) async -> Bool)? = nil
        ) {
            self.field = field
            self.required = required
            self.minLength = minLength
            self.maxLength = maxLength
            self.pattern = pattern
            self.allowedCharacters = allowedCharacters
            self.customValidator = customValidator
        }
    }
    
    // MARK: - Properties
    
    private var securityPatterns: [SecurityThreat: NSRegularExpression] = [:]
    private let auditLog: ValidationAuditLog
    
    // MARK: - Initialization
    
    public init() {
        self.auditLog = ValidationAuditLog()
        Task {
            await initializeSecurityPatterns()
        }
    }
    
    // MARK: - Public Interface
    
    /// Validate input against comprehensive security and format rules
    public func validate(_ input: String, rule: ValidationRule) async -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Basic validation
        if rule.required && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.empty(field: rule.field))
            await auditLog.logValidationFailure(field: rule.field, error: "Empty required field")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Length validation
        if let minLength = rule.minLength, trimmed.count < minLength {
            errors.append(.tooShort(field: rule.field, minimum: minLength, actual: trimmed.count))
        }
        
        if let maxLength = rule.maxLength, trimmed.count > maxLength {
            errors.append(.tooLong(field: rule.field, maximum: maxLength, actual: trimmed.count))
        }
        
        // Pattern validation
        if let pattern = rule.pattern {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) == nil {
                    errors.append(.invalidFormat(field: rule.field, expected: pattern))
                }
            }
        }
        
        // Character set validation
        if let allowedCharacters = rule.allowedCharacters {
            let illegalChars = trimmed.compactMap { char in
                if let unicodeScalar = UnicodeScalar(String(char)) {
                    return allowedCharacters.contains(unicodeScalar) ? nil : char
                }
                return char // Character without valid unicode scalar is considered illegal
            }
            if !illegalChars.isEmpty {
                errors.append(.containsIllegalCharacters(field: rule.field, characters: Array(illegalChars.prefix(5))))
            }
        }
        
        // Security threat detection
        let threatResults = await detectSecurityThreats(in: trimmed)
        for threat in threatResults {
            errors.append(.potentialSecurityThreat(field: rule.field, threat: threat))
            await auditLog.logSecurityThreat(field: rule.field, threat: threat, input: trimmed)
        }
        
        // Custom validation
        if let customValidator = rule.customValidator {
            let customValid = await customValidator(trimmed)
            if !customValid {
                errors.append(.custom(field: rule.field, message: "Custom validation failed"))
            }
        }
        
        let isValid = errors.isEmpty
        let sanitized = isValid ? await sanitizeInput(trimmed) : nil
        
        if isValid {
            await auditLog.logValidationSuccess(field: rule.field)
        } else {
            await auditLog.logValidationFailure(field: rule.field, error: errors.map(\.localizedDescription).joined(separator: "; "))
        }
        
        return ValidationResult(isValid: isValid, errors: errors, sanitized: sanitized)
    }
    
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
            for pattern in suspiciousPatterns {
                if apiKey.lowercased().contains(pattern) {
                    await auditLog.logSecurityThreat(field: "API Key", threat: .scriptInjection, input: "Suspicious API key pattern")
                    break
                }
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
        if !result.isValid && !result.errors.contains(where: { if case .invalidFormat = $0 { return true }; return false }) {
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
    public func validateNumericRange(_ value: Double, field: String, min: Double, max: Double) async -> ValidationResult {
        if value < min || value > max {
            await auditLog.logValidationFailure(field: field, error: "Value \(value) outside range [\(min), \(max)]")
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
    
    // MARK: - Private Methods
    
    /// Initialize security threat detection patterns
    private func initializeSecurityPatterns() async {
        let patterns: [SecurityThreat: String] = [
            .sqlInjection: "(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute|script|javascript|vbscript)",
            .xssAttempt: "(?i)(<script|javascript:|on\\w+\\s*=|<iframe|<object|<embed)",
            .commandInjection: "(?i)(\\||;|&|`|\\$\\(|\\$\\{|%\\(|%\\{)",
            .pathTraversal: "(\\.\\./|\\.\\\\|%2e%2e%2f|%2e%2e%5c)",
            .scriptInjection: "(?i)(eval\\s*\\(|function\\s*\\(|\\)\\s*\\{|\\}\\s*\\()",
            .htmlInjection: "(?i)(<\\w+|<\\/\\w+|&lt;|&gt;|&#x|&#\\d)"
        ]
        
        for (threat, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                securityPatterns[threat] = regex
            }
        }
    }
    
    /// Detect security threats in input
    private func detectSecurityThreats(in input: String) async -> [SecurityThreat] {
        var threats: [SecurityThreat] = []
        
        for (threat, regex) in securityPatterns {
            let range = NSRange(input.startIndex..., in: input)
            if regex.firstMatch(in: input, range: range) != nil {
                threats.append(threat)
            }
        }
        
        return threats
    }
    
    /// Sanitize input by removing potentially dangerous content
    private func sanitizeInput(_ input: String) async -> String {
        var sanitized = input
        
        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        
        // Remove control characters except tabs and newlines
        sanitized = String(sanitized.compactMap { char in
            let unicode = char.unicodeScalars.first?.value ?? 0
            if unicode < 32 && unicode != 9 && unicode != 10 && unicode != 13 {
                return nil
            }
            return char
        })
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized
    }
}

// MARK: - Validation Audit Log

/// Audit logging for validation events
public actor ValidationAuditLog {
    private var validationEvents: [ValidationEvent] = []
    private var statistics: ValidationStatistics = ValidationStatistics()
    
    struct ValidationEvent: Sendable {
        let timestamp: Date
        let field: String
        let success: Bool
        let error: String?
        let securityThreat: ValidationFramework.SecurityThreat?
    }
    
    func logValidationSuccess(field: String) {
        let event = ValidationEvent(
            timestamp: Date(),
            field: field,
            success: true,
            error: nil,
            securityThreat: nil
        )
        validationEvents.append(event)
        statistics.successCount += 1
        
        // Keep only recent events (last 1000)
        if validationEvents.count > 1000 {
            validationEvents.removeFirst(validationEvents.count - 1000)
        }
    }
    
    func logValidationFailure(field: String, error: String) {
        let event = ValidationEvent(
            timestamp: Date(),
            field: field,
            success: false,
            error: error,
            securityThreat: nil
        )
        validationEvents.append(event)
        statistics.failureCount += 1
        
        print("⚠️ Validation failure - Field: \(field), Error: \(error)")
    }
    
    func logSecurityThreat(field: String, threat: ValidationFramework.SecurityThreat, input: String) {
        let event = ValidationEvent(
            timestamp: Date(),
            field: field,
            success: false,
            error: "Security threat detected",
            securityThreat: threat
        )
        validationEvents.append(event)
        statistics.securityThreatCount += 1
        
        print("🚨 SECURITY THREAT - Field: \(field), Threat: \(threat.description), Input: \(input.prefix(50))...")
    }
    
    func getStatistics() -> ValidationStatistics {
        return statistics
    }
}

// MARK: - Common Validation Rules

extension ValidationFramework {
    /// Predefined common validation rules for frequently used fields
    @MainActor public static let commonRules = CommonRules()
    
    public struct CommonRules: Sendable {
        /// User name validation rule
        public var userName: ValidationRule {
            ValidationRule(
                field: "User Name",
                required: true,
                minLength: 2,
                maxLength: 50,
                allowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            )
        }
        
        /// File name validation rule
        public var fileName: ValidationRule {
            ValidationRule(
                field: "File Name",
                required: true,
                minLength: 1,
                maxLength: 255,
                allowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
            )
        }
        
        /// API key validation rule
        public var apiKey: ValidationRule {
            ValidationRule(
                field: "API Key",
                required: true,
                minLength: 32,
                maxLength: 128,
                allowedCharacters: CharacterSet.alphanumerics
            )
        }
        
        /// Transcription text validation rule
        public var transcriptionText: ValidationRule {
            ValidationRule(
                field: "Transcription Text",
                required: false,
                maxLength: 10000
            )
        }
        
        /// Settings value validation rule
        public var settingsValue: ValidationRule {
            ValidationRule(
                field: "Settings Value",
                required: false,
                maxLength: 500
            )
        }
    }
}

// MARK: - Supporting Types

/// Validation statistics for monitoring
public struct ValidationStatistics: Sendable {
    public var successCount: Int = 0
    public var failureCount: Int = 0
    public var securityThreatCount: Int = 0
    
    public var totalAttempts: Int {
        successCount + failureCount
    }
    
    public var successRate: Double {
        totalAttempts > 0 ? Double(successCount) / Double(totalAttempts) : 0.0
    }
}

// MARK: - Character Extensions

extension Character {
    fileprivate var isHexDigit: Bool {
        return self.isASCII && (self.isNumber || ("a"..."f").contains(self.lowercased().first!) || ("A"..."F").contains(self))
    }
}