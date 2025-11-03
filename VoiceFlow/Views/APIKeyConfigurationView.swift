import SwiftUI
import AppKit

/// Secure API key configuration view following VoiceFlow guardrails
/// Provides user-friendly interface for configuring Deepgram API credentials with comprehensive validation
@MainActor
public struct APIKeyConfigurationView: View {

    // MARK: - Properties

    @State private var apiKey: String = ""
    @State private var isConfiguring = false
    @State private var configurationMessage: String?
    @State private var isShowingKey = false
    @State private var hasExistingKey = false
    @State private var isValidInput = false
    @State private var validationError: String?
    @State private var validationInProgress = false

    private let credentialService = SecureCredentialService()
    private let validator = ValidationFramework()
    private let onConfigurationComplete: () -> Void

    // MARK: - Initialization

    public init(onConfigurationComplete: @escaping () -> Void = {}) {
        self.onConfigurationComplete = onConfigurationComplete
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Configure API Key")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Enter your Deepgram API key to enable voice transcription")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Configuration Form
            VStack(spacing: 16) {
                // API Key Input with Validation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Deepgram API Key")
                            .font(.headline)

                        Spacer()

                        // Validation Status Indicator
                        if validationInProgress {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if !apiKey.isEmpty {
                            Image(systemName: isValidInput ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isValidInput ? .green : .red)
                        }

                        Button(
                            action: {
                                isShowingKey.toggle()
                            },
                            label: {
                                Image(systemName: isShowingKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        )
                    }

                    Group {
                        if isShowingKey {
                            TextField("Enter your API key", text: $apiKey)
                        } else {
                            SecureField("Enter your API key", text: $apiKey)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .disabled(isConfiguring)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                apiKey.isEmpty ? .gray : (isValidInput ? .green : .red),
                                lineWidth: 1
                            )
                    )
                    .onChange(of: apiKey) { _, newValue in
                        validateAPIKey(newValue)
                    }

                    // Validation Error Display
                    if let error = validationError, !apiKey.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Security Information
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your API key is securely stored in the system keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !apiKey.isEmpty && isValidInput {
                            HStack {
                                Image(systemName: "shield.fill")
                                    .foregroundColor(.green)
                                Text("Valid API key format - ready for secure storage")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // Configuration Status
                if let message = configurationMessage {
                    HStack {
                        Image(systemName: hasExistingKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasExistingKey ? .green : .orange)

                        Text(message)
                            .font(.caption)
                            .foregroundColor(hasExistingKey ? .green : .orange)
                    }
                    .padding(.horizontal)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: configureAPIKey) {
                        HStack {
                            if isConfiguring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "key.fill")
                            }

                            Text(hasExistingKey ? "Update API Key" : "Configure API Key")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(apiKey.isEmpty || isConfiguring || !isValidInput || validationInProgress)

                    if hasExistingKey {
                        Button(action: testExistingKey) {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                Text("Test Current Key")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isConfiguring)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            // Help Information
            VStack(alignment: .leading, spacing: 8) {
                Text("How to get your API key:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Visit console.deepgram.com")
                    Text("2. Sign up or log in to your account")
                    Text("3. Navigate to API Keys section")
                    Text("4. Create a new API key")
                    Text("5. Copy and paste it above")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
        .task {
            await checkExistingConfiguration()
        }
    }

    // MARK: - Private Methods

    /// Validate API key with comprehensive security checks
    private func validateAPIKey(_ key: String) {
        validationInProgress = true
        validationError = nil

        Task {
            let result = await validator.validateAPIKey(key)

            await MainActor.run {
                isValidInput = result.isValid
                validationError = result.errors.first?.localizedDescription
                validationInProgress = false

                // Log validation attempt for security monitoring
                if !result.isValid && !key.isEmpty {
                    print("🔒 API key validation failed: \(result.errors.map(\.localizedDescription).joined(separator: ", "))")
                }
            }
        }
    }

    /// Configure the API key securely with validation
    private func configureAPIKey() {
        guard isValidInput else {
            configurationMessage = "Please enter a valid API key"
            return
        }

        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                // Double-check validation before storage
                let validationResult = await validator.validateAPIKey(apiKey)

                guard validationResult.isValid else {
                    await MainActor.run {
                        configurationMessage = "Validation failed: \(validationResult.errors.first?.localizedDescription ?? "Invalid API key")"
                        isConfiguring = false
                    }
                    return
                }

                // Use sanitized input if available
                let keyToStore = validationResult.sanitized ?? apiKey

                try await credentialService.configureDeepgramAPIKey(from: keyToStore)

                await MainActor.run {
                    configurationMessage = "API key configured successfully and securely stored!"
                    hasExistingKey = true
                    isConfiguring = false

                    // Clear the input field for security
                    apiKey = ""
                    isValidInput = false
                    validationError = nil

                    // Notify completion
                    onConfigurationComplete()
                }

                print("✅ API key successfully validated and configured")

            } catch {
                await MainActor.run {
                    configurationMessage = "Configuration failed: \(error.localizedDescription)"
                    isConfiguring = false
                }

                print("❌ API key configuration failed: \(error)")
            }
        }
    }

    /// Test the existing API key
    func testExistingKey() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                let existingKey = try await credentialService.getDeepgramAPIKey()
                let isValid = await credentialService.validateCredential(existingKey, for: .deepgramAPIKey)

                await MainActor.run {
                    configurationMessage = isValid ?
                        "Current API key is valid ✓" :
                        "Current API key format is invalid"
                    isConfiguring = false
                }

            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to test key: \(error.localizedDescription)"
                    isConfiguring = false
                }
            }
        }
    }

    /// Check if there's an existing configuration
    private func checkExistingConfiguration() async {
        let hasKey = await credentialService.hasDeepgramAPIKey()

        await MainActor.run {
            hasExistingKey = hasKey
            if hasKey {
                configurationMessage = "API key is already configured"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    APIKeyConfigurationView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    APIKeyConfigurationView()
        .preferredColorScheme(.dark)
}
