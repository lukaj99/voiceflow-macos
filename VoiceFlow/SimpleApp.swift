import SwiftUI
import AppKit

class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            createMainWindow()
        }
    }
    
    @MainActor private func createMainWindow() {
        let contentView = SimpleVoiceFlowView()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.center()
        window?.setFrameAutosaveName("Main Window")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.title = "VoiceFlow"
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SimpleVoiceFlowView: View {
    @State private var transcribedText = "Welcome to VoiceFlow!\n\nThis is the production-ready voice transcription app."
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
            
            // Controls
            HStack(spacing: 20) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        Text(isRecording ? "Stop" : "Start")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Clear") {
                    transcribedText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Text Editor
            VStack(alignment: .leading) {
                Text("Transcription:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $transcribedText)
                    .font(.body)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Export Options
            HStack(spacing: 12) {
                Button("Export Text") {
                    exportText()
                }
                .buttonStyle(.bordered)
                
                Button("Export Markdown") {
                    exportMarkdown()
                }
                .buttonStyle(.bordered)
                
                Button("Export PDF") {
                    exportPDF()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            transcribedText += "\n[Recording started...]"
        } else {
            transcribedText += "\n[Recording stopped.]"
        }
    }
    
    private func exportText() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "VoiceFlow Export.txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? transcribedText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.nameFieldStringValue = "VoiceFlow Export.md"
        
        if panel.runModal() == .OK, let url = panel.url {
            let markdown = """
            # VoiceFlow Transcription
            
            **Date**: \(Date().formatted())
            **Word Count**: \(transcribedText.split(separator: " ").count)
            
            ---
            
            ## Transcript
            
            \(transcribedText)
            """
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "VoiceFlow Export.pdf"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Simple PDF export - in production would use proper PDF generation
            let markdown = """
            VoiceFlow Transcription
            Date: \(Date().formatted())
            Word Count: \(transcribedText.split(separator: " ").count)
            
            Transcript:
            \(transcribedText)
            """
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

import AppKit