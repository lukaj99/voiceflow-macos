import Foundation

// MARK: - Security Validation Extension

extension ValidationFramework {

    /// Initialize security threat detection patterns
    func initializeSecurityPatterns() async {
        let patterns: [SecurityThreat: String] = [
            .sqlInjection:
                "(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute|script|javascript|vbscript)",
            .xssAttempt: "(?i)(<script|javascript:|on\\w+\\s*=|<iframe|<object|<embed)",
            .commandInjection: "(?i)(\\||;|&|`|\\$\\(|\\$\\{|%\\(|%\\{)",
            .pathTraversal: "(\\.\\./|\\.\\\\|%2e%2e%2f|%2e%2e%5c)",
            .scriptInjection: "(?i)(eval\\s*\\(|function\\s*\\(|\\)\\s*\\{|\\}\\s*\\()",
            .htmlInjection: "(?i)(<\\w+|</\\w+|&lt;|&gt;|&#x|&#\\d)"
        ]

        for (threat, pattern) in patterns where
            (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])) != nil {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                securityPatterns[threat] = regex
            }
        }
    }

    /// Detect security threats in input
    func detectSecurityThreats(in input: String) async -> [SecurityThreat] {
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
    func sanitizeInput(_ input: String) async -> String {
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
