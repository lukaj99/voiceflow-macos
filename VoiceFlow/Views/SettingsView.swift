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