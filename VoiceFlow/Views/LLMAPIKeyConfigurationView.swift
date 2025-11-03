import SwiftUI

/// LLM API key configuration view for OpenAI and Claude
/// Provides secure configuration interface following VoiceFlow guardrails
@MainActor
public struct LLMAPIKeyConfigurationView: View {

    // MARK: - Properties

    @State private var selectedProvider: LLMProvider = .openAI
    @State private var openAIAPIKey: String = ""
    @State private var claudeAPIKey: String = ""
    @State private var isConfiguring = false
    @State private var configurationMessage: String?
    @State private var isShowingOpenAIKey = false
    @State private var isShowingClaudeKey = false
    @State private var hasExistingOpenAIKey = false
    @State private var hasExistingClaudeKey = false
    @State private var isValidOpenAIInput = false
    @State private var isValidClaudeInput = false
    @State private var openAIValidationError: String?
    @State private var claudeValidationError: String?

    private let credentialService = SecureCredentialService()
    private let validator = ValidationFramework()
    private let onConfigurationComplete: () -> Void

    // MARK: - Initialization

    public init(onConfigurationComplete: @escaping () -> Void = {}) {
        self.onConfigurationComplete = onConfigurationComplete
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)

                        Text("Configure LLM API Keys")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Configure API keys for OpenAI and/or Claude to enable LLM-powered transcription enhancement")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Provider Selection
                    VStack(spacing: 16) {
                        Text("Select Provider to Configure")
                            .font(.headline)

                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(LLMProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Configuration Form
                    VStack(spacing: 20) {
                        if selectedProvider == .openAI {
                            openAIConfigurationSection
                        } else {
                            claudeConfigurationSection
                        }
                    }
                    .padding(.horizontal)

                    // Configuration Status
                    if hasExistingOpenAIKey || hasExistingClaudeKey {
                        VStack(spacing: 12) {
                            Text("Current Configuration")
                                .font(.headline)

                            HStack {
                                Image(systemName: hasExistingOpenAIKey ? "checkmark.shield.fill" : "xmark.shield.fill")
                                    .foregroundColor(hasExistingOpenAIKey ? .green : .gray)
                                Text("OpenAI")
                                Spacer()
                                Text(hasExistingOpenAIKey ? "Configured" : "Not configured")
                                    .foregroundColor(hasExistingOpenAIKey ? .green : .gray)
                            }

                            HStack {
                                Image(systemName: hasExistingClaudeKey ? "checkmark.shield.fill" : "xmark.shield.fill")
                                    .foregroundColor(hasExistingClaudeKey ? .green : .gray)
                                Text("Claude")
                                Spacer()
                                Text(hasExistingClaudeKey ? "Configured" : "Not configured")
                                    .foregroundColor(hasExistingClaudeKey ? .green : .gray)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Configuration Message
                    if let message = configurationMessage {
                        Text(message)
                            .font(.body)
                            .foregroundColor(message.contains("successfully") ? .green : .red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        if hasExistingOpenAIKey || hasExistingClaudeKey {
                            Button("Test Existing Keys") {
                                testExistingKeys()
                            }
                            .disabled(isConfiguring)
                            .buttonStyle(.bordered)
                        }

                        Button("Clear All LLM Keys") {
                            clearAllKeys()
                        }
                        .disabled(isConfiguring || (!hasExistingOpenAIKey && !hasExistingClaudeKey))
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("LLM Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onConfigurationComplete()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onConfigurationComplete()
                    }
                }
            }
            .onAppear {
                Task {
                    await checkExistingConfiguration()
                }
            }
        }
    }

    // MARK: - OpenAI Configuration Section

    private var openAIConfigurationSection: some View {
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

    // MARK: - Claude Configuration Section

    private var claudeConfigurationSection: some View {
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

                Text("Enter your Claude API key. It should start with 'sk-ant-' and be at least 64 characters long.")
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

    // MARK: - Private Methods

    /// Validate OpenAI API key input
    private func validateOpenAIInput(_ input: String) {
        Task {
            let result = await validator.validateAPIKey(input)
            let isValidFormat = input.hasPrefix("sk-") && input.count >= 51

            await MainActor.run {
                isValidOpenAIInput = result.isValid && isValidFormat
                openAIValidationError = isValidOpenAIInput ? nil : "Invalid OpenAI API key format"
            }
        }
    }

    /// Validate Claude API key input
    private func validateClaudeInput(_ input: String) {
        Task {
            let result = await validator.validateAPIKey(input)
            let isValidFormat = input.hasPrefix("sk-ant-") && input.count >= 64

            await MainActor.run {
                isValidClaudeInput = result.isValid && isValidFormat
                claudeValidationError = isValidClaudeInput ? nil : "Invalid Claude API key format"
            }
        }
    }

    /// Configure OpenAI API key
    private func configureOpenAIKey() {
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

    /// Configure Claude API key
    private func configureClaudeKey() {
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
        configurationMessage = nil

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
                configurationMessage = "Test results: " + results.joined(separator: ", ")
                isConfiguring = false
            }
        }
    }

    /// Clear all LLM API keys
    private func clearAllKeys() {
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
                    configurationMessage = "All LLM API keys cleared successfully"
                    hasExistingOpenAIKey = false
                    hasExistingClaudeKey = false
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

    /// Check existing configuration
    private func checkExistingConfiguration() async {
        let hasOpenAI = await credentialService.hasOpenAIAPIKey()
        let hasClaude = await credentialService.hasClaudeAPIKey()

        await MainActor.run {
            hasExistingOpenAIKey = hasOpenAI
            hasExistingClaudeKey = hasClaude

            if hasOpenAI || hasClaude {
                configurationMessage = "Existing LLM API keys found"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LLMAPIKeyConfigurationView()
}

#Preview("Dark Mode") {
    LLMAPIKeyConfigurationView()
        .preferredColorScheme(.dark)
}
