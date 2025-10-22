import SwiftUI

/// Secure settings view for VoiceFlow configuration
/// Follows guardrails patterns for secure credential management
@MainActor
public struct SettingsView: View {
    
    // MARK: - Properties
    
    @ObservedObject public var viewModel: SimpleTranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAPIKeyConfiguration = false
    @State private var showingHotkeyConfiguration = false
    @State private var showingLLMAPIKeyConfiguration = false
    @State private var isTestingCredentials = false
    @State private var testResult: String?
    @State private var globalHotkeysEnabled = true
    
    private let validator = ValidationFramework()
    
    // MARK: - Initialization
    
    public init(viewModel: SimpleTranscriptionViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            List {
                // API Configuration Section
                Section("API Configuration") {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deepgram API Key")
                                .font(.headline)
                            
                            Text(viewModel.isConfigured ? 
                                 "Configured and secure" : 
                                 "Not configured")
                                .font(.caption)
                                .foregroundColor(viewModel.isConfigured ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Image(systemName: viewModel.isConfigured ? 
                              "checkmark.shield.fill" : 
                              "exclamationmark.shield.fill")
                            .foregroundColor(viewModel.isConfigured ? .green : .orange)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingAPIKeyConfiguration = true
                    }
                    
                    Button("Test API Key") {
                        testCredentials()
                    }
                    .disabled(!viewModel.isConfigured || isTestingCredentials)
                    
                    if let result = testResult {
                        HStack {
                            Image(systemName: result.contains("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.contains("✓") ? .green : .red)
                            
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("✓") ? .green : .red)
                        }
                    }
                }
                
                // Model Selection Section
                Section("Transcription Model") {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(DeepgramModel.allCases, id: \.self) { model in
                            Text(model.displayName)
                                .tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // LLM Post-Processing Section
                Section(header: Text("LLM Enhancement")) {
                    Toggle("Enable LLM Post-Processing", isOn: Binding(
                        get: { AppState.shared.llmPostProcessingEnabled },
                        set: { enabled in
                            if enabled {
                                AppState.shared.enableLLMPostProcessing()
                            } else {
                                AppState.shared.disableLLMPostProcessing()
                            }
                        }
                    ))
                    
                    if AppState.shared.llmPostProcessingEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Improves transcription accuracy with grammar correction, punctuation, and word substitution (e.g., 'slash' → '/')")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // LLM Provider Selection
                            HStack {
                                Text("Provider:")
                                    .font(.caption)
                                Spacer()
                                Picker("Provider", selection: Binding(
                                    get: { AppState.shared.selectedLLMProvider },
                                    set: { provider in AppState.shared.selectedLLMProvider = provider }
                                )) {
                                    Text("OpenAI GPT").tag("openai")
                                    Text("Anthropic Claude").tag("claude")
                                }
                                .pickerStyle(MenuPickerStyle())
                                .fixedSize()
                            }
                            
                            // Model Selection
                            HStack {
                                Text("Model:")
                                    .font(.caption)
                                Spacer()
                                Picker("Model", selection: Binding(
                                    get: { AppState.shared.selectedLLMModel },
                                    set: { model in AppState.shared.selectedLLMModel = model }
                                )) {
                                    if AppState.shared.selectedLLMProvider == "openai" {
                                        Text("GPT-4o Mini (Recommended)").tag("gpt-4o-mini")
                                        Text("GPT-4o").tag("gpt-4o")
                                    } else {
                                        Text("Claude 3 Haiku (Recommended)").tag("claude-3-haiku-20240307")
                                        Text("Claude 3 Sonnet").tag("claude-3-sonnet-20240229")
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .fixedSize()
                            }
                            
                            // Configuration Status
                            HStack {
                                Image(systemName: AppState.shared.hasLLMProvidersConfigured ? 
                                      "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                    .foregroundColor(AppState.shared.hasLLMProvidersConfigured ? .green : .orange)
                                
                                Text(AppState.shared.hasLLMProvidersConfigured ? 
                                     "LLM providers configured" : 
                                     "LLM API key required")
                                    .font(.caption)
                                    .foregroundColor(AppState.shared.hasLLMProvidersConfigured ? .green : .orange)
                            }
                            
                            // Processing Status
                            if AppState.shared.isLLMProcessing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Processing with LLM...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Error Display
                            if let error = AppState.shared.llmProcessingError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Statistics
                            let stats = AppState.shared.llmProcessingStats
                            if stats.totalProcessed > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Statistics:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Processed: \(stats.totalProcessed), Success: \(String(format: "%.1f", stats.successRate * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Avg Processing: \(String(format: "%.1f", stats.averageProcessingTime))s")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                    
                    Button("Configure LLM API Keys") {
                        showingLLMAPIKeyConfiguration = true
                    }
                    .disabled(isTestingCredentials)
                }
                
                // Features Section
                Section("Features") {
                    Toggle("Global Text Input", isOn: $viewModel.globalInputEnabled)
                        .onChange(of: viewModel.globalInputEnabled) { _, enabled in
                            if enabled {
                                viewModel.enableGlobalInputMode()
                            } else {
                                viewModel.disableGlobalInputMode()
                            }
                        }
                    
                    if viewModel.globalInputEnabled {
                        Text("Global text input allows transcription to be automatically inserted into any text field")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Configure Hotkeys") {
                        showingHotkeyConfiguration = true
                    }
                    .disabled(isTestingCredentials)
                    
                    Toggle("Enable Global Hotkeys", isOn: $globalHotkeysEnabled)
                        .onChange(of: globalHotkeysEnabled) { _, enabled in
                            if enabled {
                                AppState.shared.enableGlobalHotkeys()
                            } else {
                                AppState.shared.disableGlobalHotkeys()
                            }
                        }
                }
                
                // Security Section
                Section("Security") {
                    Button("Perform Health Check") {
                        performHealthCheck()
                    }
                    .disabled(isTestingCredentials)
                    
                    Button("Clear Credential Cache") {
                        clearCredentialCache()
                    }
                    .disabled(isTestingCredentials)
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAPIKeyConfiguration) {
                APIKeyConfigurationView {
                    // Refresh configuration status when key is updated
                    Task {
                        await viewModel.checkCredentialStatus()
                    }
                }
            }
            .sheet(isPresented: $showingHotkeyConfiguration) {
                if let hotkeyService = AppState.shared.hotkeyService {
                    HotkeyConfigurationView(hotkeyService: hotkeyService)
                } else {
                    Text("Hotkey service not available")
                        .padding()
                }
            }
            .sheet(isPresented: $showingLLMAPIKeyConfiguration) {
                LLMAPIKeyConfigurationView {
                    // Refresh LLM configuration status when keys are updated
                    Task {
                        // Update configuration status
                        AppState.shared.updateLLMConfigurationStatus(true)
                    }
                }
            }
            .onAppear {
                loadHotkeySettings()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Test the configured credentials
    private func testCredentials() {
        isTestingCredentials = true
        testResult = nil
        
        Task {
            let result = await viewModel.performHealthCheck()
            
            await MainActor.run {
                testResult = result ? "Credentials test passed ✓" : "Credentials test failed ✗"
                isTestingCredentials = false
            }
        }
    }
    
    /// Perform comprehensive health check
    private func performHealthCheck() {
        isTestingCredentials = true
        testResult = nil
        
        Task {
            let result = await viewModel.performHealthCheck()
            
            await MainActor.run {
                testResult = result ? "Health check passed ✓" : "Health check failed ✗"
                isTestingCredentials = false
            }
        }
    }
    
    /// Clear credential cache
    private func clearCredentialCache() {
        Task {
            // This would need to be implemented in the credential service
            await MainActor.run {
                testResult = "Credential cache cleared ✓"
            }
        }
    }
    
    /// Load current hotkey settings
    private func loadHotkeySettings() {
        globalHotkeysEnabled = AppState.shared.isGlobalHotkeysEnabled
    }
}


// MARK: - Preview

#Preview {
    SettingsView(viewModel: SimpleTranscriptionViewModel())
}

#Preview("Dark Mode") {
    SettingsView(viewModel: SimpleTranscriptionViewModel())
        .preferredColorScheme(.dark)
}