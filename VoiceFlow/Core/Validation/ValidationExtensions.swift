import SwiftUI
import Combine

// MARK: - SwiftUI View Modifier

/// SwiftUI integration extensions for validation framework
/// Note: Common validation rules are defined in ValidationFramework.swift

/// SwiftUI view modifier for real-time input validation
public struct ValidationModifier: ViewModifier {
    let rule: ValidationFramework.ValidationRule
    let validator: ValidationFramework
    @Binding var text: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String?

    @State private var validationTask: Task<Void, Never>?

    public func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newValue in
                validateInput(newValue)
            }
            .onDisappear {
                validationTask?.cancel()
            }
    }

    private func validateInput(_ input: String) {
        validationTask?.cancel()

        validationTask = Task {
            // Debounce validation for performance
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if !Task.isCancelled {
                let result = await validator.validate(input, rule: rule)

                await MainActor.run {
                    isValid = result.isValid
                    errorMessage = result.errors.first?.localizedDescription
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add real-time validation to any input field
    public func validated(
        text: Binding<String>,
        rule: ValidationFramework.ValidationRule,
        validator: ValidationFramework,
        isValid: Binding<Bool>,
        errorMessage: Binding<String?>
    ) -> some View {
        modifier(ValidationModifier(
            rule: rule,
            validator: validator,
            text: text,
            isValid: isValid,
            errorMessage: errorMessage
        ))
    }
}

// MARK: - Validation State Observable

/// Observable object for managing validation state in SwiftUI
@MainActor
public class ValidationState: ObservableObject {
    @Published public var isValid = false
    @Published public var errorMessage: String?
    @Published public var isValidating = false

    private let validator: ValidationFramework
    private let rule: ValidationFramework.ValidationRule
    private var validationTask: Task<Void, Never>?

    public init(validator: ValidationFramework, rule: ValidationFramework.ValidationRule) {
        self.validator = validator
        self.rule = rule
    }

    public func validate(_ input: String) {
        isValidating = true
        validationTask?.cancel()

        validationTask = Task {
            let result = await validator.validate(input, rule: rule)

            await MainActor.run {
                self.isValid = result.isValid
                self.errorMessage = result.errors.first?.localizedDescription
                self.isValidating = false
            }
        }
    }

    deinit {
        validationTask?.cancel()
    }
}

// MARK: - Validated Text Field

/// Pre-built validated text field component
public struct ValidatedTextField: View {
    let title: String
    let rule: ValidationFramework.ValidationRule
    let validator: ValidationFramework

    @Binding var text: String
    @State private var validationState: ValidationState
    @State private var isSecure: Bool

    public init(
        title: String,
        text: Binding<String>,
        rule: ValidationFramework.ValidationRule,
        validator: ValidationFramework,
        isSecure: Bool = false
    ) {
        self.title = title
        self._text = text
        self.rule = rule
        self.validator = validator
        self.isSecure = isSecure
        self._validationState = State(initialValue: ValidationState(validator: validator, rule: rule))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                if validationState.isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if !text.isEmpty {
                    Image(systemName: validationState.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(
                            validationState.isValid ? .green : .red
                        )
                }
            }

            Group {
                if isSecure {
                    SecureField("Enter \(title.lowercased())", text: $text)
                } else {
                    TextField("Enter \(title.lowercased())", text: $text)
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        text.isEmpty ? .gray : (validationState.isValid ? .green : .red),
                        lineWidth: 1
                    )
            )
            .onChange(of: text) { _, newValue in
                validationState.validate(newValue)
            }

            if let errorMessage = validationState.errorMessage, !text.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Batch Validation Helper

/// Helper for batch validation in forms
@MainActor
public class FormValidationManager: ObservableObject {
    @Published public var isValid = false
    @Published public var errors: [String] = []

    private let validator: ValidationFramework
    private var fields: [(String, ValidationFramework.ValidationRule)] = []

    public init(validator: ValidationFramework) {
        self.validator = validator
    }

    public func addField(_ value: String, rule: ValidationFramework.ValidationRule) {
        fields.append((value, rule))
    }

    public func validateAll() async {
        let results = await validator.validateBatch(fields)

        let allValid = results.allSatisfy(\.isValid)
        let allErrors = results.flatMap(\.errors).map(\.localizedDescription)

        await MainActor.run {
            self.isValid = allValid
            self.errors = allErrors
        }
    }

    public func clearFields() {
        fields.removeAll()
    }
}

// MARK: - Validation Result Extensions

extension ValidationFramework.ValidationResult {
    /// Convenient property for UI binding
    public var displayError: String? {
        errors.first?.localizedDescription
    }

    /// Get all error messages combined
    public var allErrorMessages: String {
        errors.map(\.localizedDescription).joined(separator: "\n")
    }
}

// MARK: - String Validation Extensions

extension String {
    /// Quick validation using common rules
    public func validate(
        with rule: ValidationFramework.ValidationRule,
        using validator: ValidationFramework
    ) async -> ValidationFramework.ValidationResult {
        return await validator.validate(self, rule: rule)
    }

    /// Check if string is a valid API key format
    public var isValidAPIKeyFormat: Bool {
        count >= 32 && count <= 128 && allSatisfy { $0.isHexDigit || $0.isLetter || $0.isNumber }
    }

    /// Check if string contains potentially dangerous content
    public var containsSecurityThreats: Bool {
        let dangerousPatterns = [
            "<script", "javascript:", "onload=", "onerror=",
            "SELECT ", "INSERT ", "UPDATE ", "DELETE ",
            "../", "..\\", "%2e%2e",
            "eval(", "function(", "${", "$("
        ]

        let lowercased = self.lowercased()
        return dangerousPatterns.contains { lowercased.contains($0.lowercased()) }
    }
}

// MARK: - Character Set Extensions

extension CharacterSet {
    /// Alphanumeric characters plus common safe symbols
    public static var safeInput: CharacterSet {
        return .alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_.@"))
    }

    /// Characters allowed in file names
    public static var fileName: CharacterSet {
        return .alphanumerics
            .union(CharacterSet(charactersIn: "-_. ()"))
    }

    /// Characters allowed in API keys
    public static var apiKey: CharacterSet {
        return .alphanumerics
    }
}

// MARK: - Debugging and Testing Helpers

#if DEBUG
extension ValidationFramework {
    /// Test validation with various malicious inputs (for testing only)
    public func testSecurityValidation() async {
        let maliciousInputs = [
            "<script>alert('xss')</script>",
            "'; DROP TABLE users; --",
            "../../../etc/passwd",
            "javascript:alert('xss')",
            "${eval(alert('test'))}",
            "onload=\"alert('xss')\"",
            "UNION SELECT password FROM users",
            "../../windows/system32",
            "%3Cscript%3Ealert('xss')%3C/script%3E"
        ]

        print("🔍 Testing security validation...")

        for input in maliciousInputs {
            let result = await validate(input, rule: ValidationFramework.commonRules.transcriptionText)
            if !result.isValid {
                print("✅ Blocked malicious input: \(input.prefix(30))...")
            } else {
                print("⚠️ Failed to block: \(input.prefix(30))...")
            }
        }

        let stats = await getValidationStatistics()
        print(
            "📊 Validation stats - Success: \(stats.successCount), " +
            "Failures: \(stats.failureCount), Threats: \(stats.securityThreatCount)"
        )
    }
}
#endif
