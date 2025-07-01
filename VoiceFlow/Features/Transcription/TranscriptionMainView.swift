import SwiftUI
import AppKit

public struct TranscriptionMainView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var searchText = ""
    @State private var showingExportMenu = false
    @State private var selectedRange: NSRange?
    @FocusState private var isEditorFocused: Bool
    
    // Layout constants
    private let windowSize = CGSize(width: 800, height: 600)
    private let minWindowSize = CGSize(width: 600, height: 400)
    private let maxWindowSize = CGSize(width: 1400, height: 1000)
    
    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // Liquid Glass background
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                // Header toolbar
                headerToolbar
                    .frame(height: 52)
                    .background(.ultraThinMaterial)
                
                Divider()
                
                // Main content area
                GeometryReader { geometry in
                    HSplitView {
                        // Transcription editor
                        transcriptionEditor
                            .frame(minWidth: 400)
                        
                        // Session history sidebar
                        if geometry.size.width > 800 {
                            sessionHistorySidebar
                                .frame(width: 250)
                                .frame(minWidth: 200, maxWidth: 300)
                        }
                    }
                }
                
                Divider()
                
                // Bottom status bar
                statusBar
                    .frame(height: 28)
                    .background(.ultraThinMaterial)
            }
        }
        .frame(
            minWidth: minWindowSize.width,
            minHeight: minWindowSize.height,
            idealWidth: windowSize.width,
            idealHeight: windowSize.height,
            maxWidth: maxWindowSize.width,
            maxHeight: maxWindowSize.height
        )
        .onAppear {
            isEditorFocused = true
        }
    }
    
    // MARK: - Header Toolbar
    
    private var headerToolbar: some View {
        HStack(spacing: 16) {
            // Transcription controls
            Button(action: toggleTranscription) {
                Image(systemName: viewModel.isTranscribing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.isTranscribing ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .help(viewModel.isTranscribing ? "Stop Transcription" : "Start Transcription")
            
            Button(action: { viewModel.clearTranscription() }) {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.transcribedText.isEmpty)
            .help("Clear Transcription")
            
            Divider()
                .frame(height: 20)
            
            // Formatting controls
            Button(action: {}) {
                Image(systemName: "bold")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Bold")
            
            Button(action: {}) {
                Image(systemName: "italic")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Italic")
            
            Button(action: {}) {
                Image(systemName: "list.bullet")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Bullet List")
            
            Spacer()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .cornerRadius(6)
            .frame(width: 200)
            
            // Export button
            Button(action: { showingExportMenu = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Export")
            .popover(isPresented: $showingExportMenu) {
                exportMenu
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Transcription Editor
    
    private var transcriptionEditor: some View {
        VStack(spacing: 0) {
            // Editor header
            HStack {
                Label("Transcript", systemImage: "text.alignleft")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isTranscribing {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                        Text("Recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Text editor
            TranscriptionTextEditor(
                text: $viewModel.transcribedText,
                isTranscribing: viewModel.isTranscribing,
                isFocused: _isEditorFocused
            )
            .padding()
        }
    }
    
    // MARK: - Session History Sidebar
    
    private var sessionHistorySidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Label("History", systemImage: "clock")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Sessions list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(mockSessions) { session in
                        SessionRow(session: session)
                            .onTapGesture {
                                loadSession(session)
                            }
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Word count
            Label("\(viewModel.wordCount) words", systemImage: "doc.text")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 16)
            
            // Duration
            Label(formatDuration(viewModel.sessionDuration), systemImage: "timer")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 16)
            
            // Confidence
            if viewModel.averageConfidence > 0 {
                Label("\(Int(viewModel.averageConfidence * 100))% confidence", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Audio level indicator
            if viewModel.isTranscribing {
                AudioLevelIndicator(level: viewModel.currentAudioLevel)
                    .frame(width: 100, height: 16)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Export Menu
    
    private var exportMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export Format")
                .font(.headline)
                .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                ExportMenuItem(title: "Plain Text", subtitle: ".txt", action: exportAsText)
                ExportMenuItem(title: "Markdown", subtitle: ".md", action: exportAsMarkdown)
                ExportMenuItem(title: "Word Document", subtitle: ".docx", action: exportAsWord)
                ExportMenuItem(title: "PDF", subtitle: ".pdf", action: exportAsPDF)
                ExportMenuItem(title: "Subtitles", subtitle: ".srt", action: exportAsSRT)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 250)
    }
    
    // MARK: - Actions
    
    private func toggleTranscription() {
        Task {
            if viewModel.isTranscribing {
                await viewModel.stopTranscription()
            } else {
                await viewModel.startTranscription()
            }
        }
    }
    
    private func loadSession(_ session: MockSession) {
        viewModel.transcribedText = session.content
    }
    
    private func exportAsText() {
        showingExportMenu = false
        saveToFile(content: viewModel.exportAsText(), fileType: "txt")
    }
    
    private func exportAsMarkdown() {
        showingExportMenu = false
        saveToFile(content: viewModel.exportAsMarkdown(), fileType: "md")
    }
    
    private func exportAsWord() {
        showingExportMenu = false
        // TODO: Implement DOCX export
    }
    
    private func exportAsPDF() {
        showingExportMenu = false
        // TODO: Implement PDF export
    }
    
    private func exportAsSRT() {
        showingExportMenu = false
        // TODO: Implement SRT export
    }
    
    private func saveToFile(content: String, fileType: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Transcription"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "transcription.\(fileType)"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    // MARK: - Mock Data
    
    private var mockSessions: [MockSession] {
        [
            MockSession(date: Date().addingTimeInterval(-3600), title: "Team Meeting", duration: 1800, content: "Discussion about Q1 goals..."),
            MockSession(date: Date().addingTimeInterval(-7200), title: "Client Call", duration: 2400, content: "Project requirements review..."),
            MockSession(date: Date().addingTimeInterval(-86400), title: "Brainstorming", duration: 3600, content: "New feature ideas...")
        ]
    }
}

// MARK: - Supporting Views

struct TranscriptionTextEditor: NSViewRepresentable {
    @Binding var text: String
    let isTranscribing: Bool
    @FocusState var isFocused: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        if textView.string != text {
            textView.string = text
            
            // Auto-scroll to bottom when transcribing
            if isTranscribing {
                textView.scrollToEndOfDocument(nil)
            }
        }
        
        // Update focus state
        if isFocused && !textView.window?.firstResponder.map({ $0 === textView }) ?? false {
            textView.window?.makeFirstResponder(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranscriptionTextEditor
        
        init(_ parent: TranscriptionTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

struct SessionRow: View {
    let session: MockSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                Spacer()
                Text(session.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(session.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(formatDuration(session.duration), systemImage: "timer")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.quaternary)
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

struct ExportMenuItem: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Mock Data Models

struct MockSession: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let duration: TimeInterval
    let content: String
}