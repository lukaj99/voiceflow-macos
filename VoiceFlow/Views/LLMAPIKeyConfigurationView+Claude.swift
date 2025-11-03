import SwiftUI

// MARK: - Claude Configuration Extension

extension LLMAPIKeyConfigurationView {

    var claudeConfigurationSection: some View {
        VStack(spacing: 16) {
            Text("Claude API Key Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Group {
                        if isShowingClaudeKey {
                            TextField("sk-ant-...", text: $claudeAPIKey)
                        } else {
                            SecureField("sk-ant-...", text: $claudeAPIKey)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: claudeAPIKey) { _, newValue in
                        validateClaudeInput(newValue)
                    }

                    Button(
                        action: { isShowingClaudeKey.toggle() },
                        label: {
                            Image(systemName: isShowingClaudeKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    )
                }

                if let error = claudeValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text(
                    "Enter your Claude API key. It should start with 'sk-ant-' " +
                    "and be at least 64 characters long."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(
                action: { configureClaudeKey() },
                label: {
                    if isConfiguring && selectedProvider == .claude {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Configuring...")
                    }
                    } else {
                        Text("Configure Claude API Key")
                    }
                }
            )
            .buttonStyle(.borderedProminent)
            .disabled(!isValidClaudeInput || isConfiguring)

            if hasExistingClaudeKey && !claudeAPIKey.isEmpty {
                Button("Test Claude Key") {
                    testClaudeKey()
                }
                .disabled(isConfiguring)
                .buttonStyle(.bordered)
            }
        }
    }

    /// Validate Claude API key input
    func validateClaudeInput(_ input: String) {
        Task {
            let result = await validator.validateAPIKey(input)
            let isValidFormat = input.hasPrefix("sk-ant-") && input.count >= 64

            await MainActor.run {
                isValidClaudeInput = result.isValid && isValidFormat
                claudeValidationError = isValidClaudeInput ? nil : "Invalid Claude API key format"
            }
        }
    }

    /// Configure Claude API key
    func configureClaudeKey() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                try await credentialService.configureLLMAPIKey(from: claudeAPIKey, for: .claude)

                await MainActor.run {
                    configurationMessage = "Claude API key configured successfully!"
                    hasExistingClaudeKey = true
                    isConfiguring = false

                    // Clear the input field for security
                    claudeAPIKey = ""
                    isValidClaudeInput = false
                    claudeValidationError = nil

                    // Notify completion
                    onConfigurationComplete()
                }

                print("✅ Claude API key successfully configured")

            } catch {
                await MainActor.run {
                    configurationMessage = "Claude configuration failed: \(error.localizedDescription)"
                    isConfiguring = false
                }

                print("❌ Claude API key configuration failed: \(error)")
            }
        }
    }

    /// Test existing Claude key
    func testClaudeKey() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                let existingKey = try await credentialService.getClaudeAPIKey()
                let isValid = await credentialService.validateCredential(existingKey, for: .claudeAPIKey)

                await MainActor.run {
                    configurationMessage = isValid ?
                        "Claude API key is valid ✓" :
                        "Claude API key format is invalid"
                    isConfiguring = false
                }

            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to test Claude key: \(error.localizedDescription)"
                    isConfiguring = false
                }
            }
        }
    }

    /// Test all existing keys
    func testExistingKeys() {
        isConfiguring = true
        configurationMessage = "Testing API keys..."

        Task {
            var results: [String] = []

            if hasExistingOpenAIKey {
                do {
                    let key = try await credentialService.getOpenAIAPIKey()
                    let isValid = await credentialService.validateCredential(key, for: .openAIAPIKey)
                    results.append("OpenAI: \(isValid ? "✓" : "✗")")
                } catch {
                    results.append("OpenAI: Error")
                }
            }

            if hasExistingClaudeKey {
                do {
                    let key = try await credentialService.getClaudeAPIKey()
                    let isValid = await credentialService.validateCredential(key, for: .claudeAPIKey)
                    results.append("Claude: \(isValid ? "✓" : "✗")")
                } catch {
                    results.append("Claude: Error")
                }
            }

            await MainActor.run {
                configurationMessage = results.joined(separator: ", ")
                isConfiguring = false
            }
        }
    }

    /// Clear all LLM keys
    func clearAllKeys() {
        isConfiguring = true
        configurationMessage = nil

        Task {
            do {
                if hasExistingOpenAIKey {
                    try await credentialService.remove(for: .openAIAPIKey)
                }
                if hasExistingClaudeKey {
                    try await credentialService.remove(for: .claudeAPIKey)
                }

                await MainActor.run {
                    hasExistingOpenAIKey = false
                    hasExistingClaudeKey = false
                    configurationMessage = "All LLM API keys cleared successfully"
                    isConfiguring = false
                }

                print("✅ All LLM API keys cleared")

            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to clear keys: \(error.localizedDescription)"
                    isConfiguring = false
                }

                print("❌ Failed to clear LLM API keys: \(error)")
            }
        }
    }

    /// Check existing configuration on load
    func checkExistingConfiguration() async {
        hasExistingOpenAIKey = await credentialService.hasOpenAIAPIKey()
        hasExistingClaudeKey = await credentialService.hasClaudeAPIKey()
    }
}
