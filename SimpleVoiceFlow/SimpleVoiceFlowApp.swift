
import SwiftUI

@main
struct SimpleVoiceFlowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var transcribedText = "Welcome to VoiceFlow!"
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundColor(isRecording ? .red : .blue)
                Text("VoiceFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding()
            
            // Transcription area
            ScrollView {
                TextEditor(text: $transcribedText)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(minHeight: 200)
            
            // Controls
            HStack(spacing: 20) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        Text(isRecording ? "Stop" : "Start")
                    }
                    .font(.title2)
                    .padding()
                    .background(isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button("Clear") {
                    transcribedText = ""
                }
                .font(.title2)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Export") {
                    exportText()
                }
                .font(.title2)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Status
            Text(isRecording ? "🔴 Recording..." : "⏸️ Ready to record")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            transcribedText += "\n[Recording started - Voice transcription would appear here in full version]"
        } else {
            transcribedText += "\n[Recording stopped]"
        }
    }
    
    private func exportText() {
        let panel = NSSavePanel()
        panel.title = "Export Transcription"
        panel.nameFieldStringValue = "transcription.txt"
        panel.allowedContentTypes = [.plainText]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? transcribedText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

#Preview {
    ContentView()
}
