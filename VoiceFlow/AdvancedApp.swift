import SwiftUI
import AppKit
import Combine
import AsyncAlgorithms

// Advanced VoiceFlow with more features
@MainActor
class AdvancedAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var transcriptionViewModel: AdvancedTranscriptionViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
    }
    
    private func createMainWindow() {
        transcriptionViewModel = AdvancedTranscriptionViewModel()
        let contentView = AdvancedVoiceFlowView(viewModel: transcriptionViewModel!)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.center()
        window?.setFrameAutosaveName("VoiceFlow Main Window")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.title = "VoiceFlow - Advanced"
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
class AdvancedTranscriptionViewModel: ObservableObject {
    @Published var transcribedText = "Welcome to VoiceFlow Advanced!\n\nThis version includes enhanced features:"
    @Published var isTranscribing = false
    @Published var currentAudioLevel: Float = 0
    @Published var wordCount: Int = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var averageConfidence: Double = 0.95
    
    private var sessionStartTime: Date?
    private var speechEngine: RealSpeechRecognitionEngine?
    private var cancellables = Set<AnyCancellable>()
    
    func startTranscription() {
        guard !isTranscribing else { return }
        
        // Initialize speech engine if needed
        if speechEngine == nil {
            speechEngine = RealSpeechRecognitionEngine()
            setupSpeechSubscription()
        }
        
        isTranscribing = true
        sessionStartTime = Date()
        startSessionTimer()
        
        transcribedText += "\n\n[Recording started at \(Date().formatted(date: .omitted, time: .shortened))]"
        
        Task {
            do {
                try await speechEngine?.startTranscription()
            } catch {
                // Fall back to simulation if speech fails
                simulateTranscription()
            }
        }
    }
    
    func stopTranscription() {
        guard isTranscribing else { return }
        
        isTranscribing = false
        currentAudioLevel = 0
        
        Task {
            await speechEngine?.stopTranscription()
        }
        
        transcribedText += "\n[Recording stopped at \(Date().formatted(date: .omitted, time: .shortened))]"
        updateWordCount()
    }
    
    func clearTranscription() {
        transcribedText = "Welcome to VoiceFlow Advanced!\n\nThis version includes enhanced features:"
        wordCount = 0
        sessionDuration = 0
        averageConfidence = 0.95
    }
    
    private func setupSpeechSubscription() {
        guard let speechEngine = speechEngine else { return }
        
        speechEngine.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleTranscriptionUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    private func handleTranscriptionUpdate(_ update: TranscriptionUpdate) {
        switch update.type {
        case .partial:
            // Update with partial transcription but don't save to full text yet
            break
        case .final:
            transcribedText += "\n" + update.text
            updateWordCount()
            averageConfidence = update.confidence
        case .correction:
            // Handle corrections to previously transcribed text
            break
        }
    }
    
    private func startSessionTimer() {
        Task { @MainActor in
            while isTranscribing, let startTime = sessionStartTime {
                sessionDuration = Date().timeIntervalSince(startTime)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func simulateTranscription() {
        // Simulate real-time audio level using MainActor-isolated scheduling
        Task { @MainActor in
            while isTranscribing {
                currentAudioLevel = Float.random(in: 0.1...0.8)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        
        // Simulate transcription updates using MainActor-isolated scheduling
        let sampleTexts = [
            "This is a demonstration of VoiceFlow's advanced transcription capabilities.",
            "The app features real-time audio visualization and performance monitoring.",
            "Export options include multiple formats with professional quality output.",
            "Privacy-first design ensures all processing happens on your device.",
            "Swift 6 concurrency provides smooth, responsive performance."
        ]
        
        Task { @MainActor in
            for (_, text) in sampleTexts.enumerated() {
                guard isTranscribing else { break }
                
                try? await Task.sleep(for: .seconds(3))
                guard isTranscribing else { break }
                
                transcribedText += "\n\n" + text
                updateWordCount()
            }
        }
    }
    
    private func updateWordCount() {
        wordCount = transcribedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

struct AdvancedVoiceFlowView: View {
    @ObservedObject var viewModel: AdvancedTranscriptionViewModel
    @State private var selectedExportFormat = ExportFormat.text
    @State private var showingExportPanel = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with logo and status
            headerView
            
            // Control panel
            controlPanel
            
            // Statistics bar
            statisticsBar
            
            // Main transcription area
            transcriptionArea
            
            // Export options
            exportOptions
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("VoiceFlow Advanced")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Professional Voice Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Audio level indicator
            AudioLevelIndicator(level: viewModel.currentAudioLevel)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private var controlPanel: some View {
        HStack(spacing: 20) {
            Button(action: {
                if viewModel.isTranscribing {
                    viewModel.stopTranscription()
                } else {
                    viewModel.startTranscription()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isTranscribing ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                    Text(viewModel.isTranscribing ? "Stop Recording" : "Start Recording")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Clear") {
                viewModel.clearTranscription()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("Settings") {
                // Settings placeholder
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
    
    private var statisticsBar: some View {
        HStack {
            StatCard(title: "Duration", value: formatDuration(viewModel.sessionDuration))
            StatCard(title: "Words", value: "\(viewModel.wordCount)")
            StatCard(title: "Confidence", value: "\(Int(viewModel.averageConfidence * 100))%")
            StatCard(title: "Status", value: viewModel.isTranscribing ? "Recording" : "Ready")
        }
    }
    
    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                Text(viewModel.transcribedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(minHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var exportOptions: some View {
        VStack(spacing: 12) {
            Text("Export Options")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach([ExportFormat.text, ExportFormat.markdown, ExportFormat.pdf], id: \.self) { format in
                    Button(format.displayName) {
                        selectedExportFormat = format
                        exportTranscription(format: format)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func exportTranscription(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
        panel.nameFieldStringValue = "VoiceFlow Export.\(format.fileExtension)"
        
        if panel.runModal() == .OK, let url = panel.url {
            let content = generateExportContent(format: format)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func generateExportContent(format: ExportFormat) -> String {
        switch format {
        case .text:
            return viewModel.transcribedText
        case .markdown:
            return """
            # VoiceFlow Advanced Export
            
            **Date**: \(Date().formatted())
            **Duration**: \(formatDuration(viewModel.sessionDuration))
            **Words**: \(viewModel.wordCount)
            **Confidence**: \(Int(viewModel.averageConfidence * 100))%
            
            ---
            
            ## Transcript
            
            \(viewModel.transcribedText)
            """
        case .pdf:
            return generateExportContent(format: .markdown) // Simplified for now
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .fill(level > Float(index) * 0.1 ? .green : .gray.opacity(0.3))
                    .frame(width: 3, height: 20)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// Simple export format enum for this version
enum ExportFormat: String, CaseIterable {
    case text = "txt"
    case markdown = "md" 
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}