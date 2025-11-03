import SwiftUI

/// Simplified settings view for debugging
public struct SimpleSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("VoiceFlow Settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                Text("API Configuration")
                    .font(.headline)

                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                    Text("Deepgram API Key")
                    Spacer()
                    Text("Configured ✓")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Text("Transcription Model")
                    .font(.headline)

                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("Nova-3 General")
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Text("Features")
                    .font(.headline)

                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.orange)
                    Text("Global Text Input")
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}
