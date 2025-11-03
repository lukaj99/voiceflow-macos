import SwiftUI

/// Modern UI for secure voice transcription
public struct ContentView: View {
    @StateObject private var viewModel = SimpleTranscriptionViewModel()
    @State private var showSettings = false

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundColor(viewModel.isRecording ? .red : .blue)
                Text("VoiceFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding()

            // Status and Controls
            VStack(spacing: 15) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(connectionStatusColor(for: viewModel.connectionStatus))
                        .frame(width: 12, height: 12)
                    Text(viewModel.connectionStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.connectionStatus)

                // Audio Level Indicator
                if viewModel.isRecording {
                    VStack {
                        Text("Audio Level")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ProgressView(value: viewModel.audioLevel, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 8)
                    }
                }

                // Configuration Status
                HStack {
                    Image(systemName: viewModel.isConfigured ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(viewModel.isConfigured ? .green : .orange)
                    Text(viewModel.isConfigured ? "Secure credentials configured" : "Credentials not configured")
                        .font(.caption)
                        .foregroundColor(viewModel.isConfigured ? .secondary : .orange)
                }

                // LLM Processing Status
                if AppState.shared.llmPostProcessingEnabled {
                    HStack {
                        Image(
                            systemName: AppState.shared.hasLLMProvidersConfigured ?
                                "brain.head.profile.fill" : "brain.head.profile"
                        )
                            .foregroundColor(AppState.shared.hasLLMProvidersConfigured ? .purple : .gray)

                        if AppState.shared.isLLMProcessing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Enhancing with LLM...")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        } else {
                            Text(AppState.shared.hasLLMProvidersConfigured ?
                                 "LLM enhancement ready" :
                                 "LLM enhancement requires API key")
                                .font(.caption)
                                .foregroundColor(AppState.shared.hasLLMProvidersConfigured ? .purple : .gray)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: AppState.shared.isLLMProcessing)
                }

                // Main Controls
                HStack(spacing: 20) {
                    // Settings Button
                    Button("Settings") {
                        showSettings = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRecording)

                    // Start/Stop Button
                    Button(
                        action: {
                            Task {
                                if viewModel.isRecording {
                                    viewModel.stopRecording()
                                } else {
                                    await viewModel.startRecording()
                                }
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                Text(viewModel.isRecording ? "Stop" : "Start")
                            }
                        }
                    )
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isConfigured)

                    // Clear Button
                    Button("Clear") {
                        viewModel.clearTranscription()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRecording)
                }

                // API Key Configuration prompt (if not configured)
                if !viewModel.isConfigured {
                    VStack(spacing: 8) {
                        Text("API key required for transcription")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Button("Configure API Key") {
                            showSettings = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                        .font(.caption)
                    }
                }
            }

            // Error Display
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }

            // LLM Error Display
            if let llmError = AppState.shared.llmProcessingError {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.red)
                    Text("LLM Enhancement Error: \(llmError)")
                        .font(.caption)
                        .foregroundColor(.red)

                    Button("Dismiss") {
                        AppState.shared.setLLMProcessingError(nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }

            // Transcription Display
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    Text(
                        viewModel.transcriptionText.isEmpty ?
                            "Transcribed text will appear here..." : viewModel.transcriptionText
                    )
                        .font(.body)
                        .foregroundColor(viewModel.transcriptionText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 200)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
                .frame(width: 500, height: 600)
        }
    }

    /// Get color for connection status
    private func connectionStatusColor(for status: String) -> Color {
        switch status {
        case "Connected": return .green
        case "Connecting": return .orange
        case "Reconnecting": return .yellow
        case "Error": return .red
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
