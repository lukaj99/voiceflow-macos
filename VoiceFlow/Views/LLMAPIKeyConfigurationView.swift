import SwiftUI

/// LLM API key configuration view for OpenAI and Claude
/// Provides secure configuration interface following VoiceFlow guardrails
@MainActor
public struct LLMAPIKeyConfigurationView: View {

    // MARK: - Properties

    @State var selectedProvider: LLMProvider = .openAI
    @State var openAIAPIKey: String = ""
    @State var claudeAPIKey: String = ""
    @State var isConfiguring = false
    @State var configurationMessage: String?
    @State var isShowingOpenAIKey = false
    @State var isShowingClaudeKey = false
    @State var hasExistingOpenAIKey = false
    @State var hasExistingClaudeKey = false
    @State var isValidOpenAIInput = false
    @State var isValidClaudeInput = false
    @State var openAIValidationError: String?
    @State var claudeValidationError: String?

    let credentialService = SecureCredentialService()
    let validator = ValidationFramework()
    let onConfigurationComplete: () -> Void

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

                        Text(
                            "Configure API keys for OpenAI and/or Claude to enable LLM-powered "
                            + "transcription enhancement"
                        )
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

}

// MARK: - Preview

#Preview {
    LLMAPIKeyConfigurationView()
}

#Preview("Dark Mode") {
    LLMAPIKeyConfigurationView()
        .preferredColorScheme(.dark)
}
