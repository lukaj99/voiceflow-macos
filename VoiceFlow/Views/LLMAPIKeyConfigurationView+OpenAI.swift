import SwiftUI

// MARK: - OpenAI Configuration Extension

extension LLMAPIKeyConfigurationView {

    var openAIConfigurationSection: some View {
        VStack(spacing: 16) {
            Text("OpenAI API Key Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Group {
                        if isShowingOpenAIKey {
                            TextField("sk-...", text: $openAIAPIKey)
                        } else {
                            SecureField("sk-...", text: $openAIAPIKey)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: openAIAPIKey) { _, newValue in
                        validateOpenAIInput(newValue)
                    }

                    Button(
                        action: { isShowingOpenAIKey.toggle() },
                        label: {
                            Image(systemName: isShowingOpenAIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    )
                }

                if let error = openAIValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text("Enter your OpenAI API key. It should start with 'sk-' and be at least 51 characters long.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(
                action: { configureOpenAIKey() },
                label: {
                    if isConfiguring && selectedProvider == .openAI {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Configuring...")
                    }
                    } else {
                        Text("Configure OpenAI API Key")
                    }
                }
            )
            .buttonStyle(.borderedProminent)
            .disabled(!isValidOpenAIInput || isConfiguring)

            if hasExistingOpenAIKey && !openAIAPIKey.isEmpty {
                Button("Test OpenAI Key") {
                    testOpenAIKey()
                }
                .disabled(isConfiguring)
                .buttonStyle(.bordered)
            }
        }
    }

    /// Validate OpenAI API key input
    func validateOpenAIInput(_ input: String) {
        Task {
            let result = await validator.validateAPIKey(input)
            let isValidFormat = input.hasPrefix("sk-") && input.count >= 51

            await MainActor.run {
                isValidOpenAIInput = result.isValid && isValidFormat
                openAIValidationError = isValidOpenAIInput ? nil : "Invalid OpenAI API key format"
            }
        }
    }

    /// Configure OpenAI API key
    func configureOpenAIKey() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                try await credentialService.configureLLMAPIKey(from: openAIAPIKey, for: .openAI)

                await MainActor.run {
                    configurationMessage = "OpenAI API key configured successfully!"
                    hasExistingOpenAIKey = true
                    isConfiguring = false

                    // Clear the input field for security
                    openAIAPIKey = ""
                    isValidOpenAIInput = false
                    openAIValidationError = nil

                    // Notify completion
                    onConfigurationComplete()
                }

                print("✅ OpenAI API key successfully configured")

            } catch {
                await MainActor.run {
                    configurationMessage = "OpenAI configuration failed: \(error.localizedDescription)"
                    isConfiguring = false
                }

                print("❌ OpenAI API key configuration failed: \(error)")
            }
        }
    }

    /// Test existing OpenAI key
    func testOpenAIKey() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                let existingKey = try await credentialService.getOpenAIAPIKey()
                let isValid = await credentialService.validateCredential(existingKey, for: .openAIAPIKey)

                await MainActor.run {
                    configurationMessage = isValid ?
                        "OpenAI API key is valid ✓" :
                        "OpenAI API key format is invalid"
                    isConfiguring = false
                }

            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to test OpenAI key: \(error.localizedDescription)"
                    isConfiguring = false
                }
            }
        }
    }
}
