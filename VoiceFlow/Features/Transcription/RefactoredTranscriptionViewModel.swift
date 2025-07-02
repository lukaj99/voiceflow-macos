import Foundation
import Combine
import SwiftUI

/// Refactored TranscriptionViewModel focused on UI state management following MVVM and Single Responsibility Principle
@MainActor
public class RefactoredTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    
    @Published public var transcribedText = ""
    @Published public var isTranscribing = false
    @Published public var currentAudioLevel: Float = 0
    @Published public var error: Error?
    
    // MARK: - Dependencies (Injected Services)
    
    private let transcriptionEngine: TranscriptionEngineProtocol
    private let sessionManager: SessionManager
    private let exportService: TranscriptionExportService
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    public var currentSession: TranscriptionSession? {
        sessionManager.currentSession
    }
    
    public var sessionDuration: TimeInterval {
        sessionManager.sessionDuration
    }
    
    public var wordCount: Int {
        sessionManager.wordCount
    }
    
    public var averageConfidence: Double {
        sessionManager.averageConfidence
    }
    
    // MARK: - Initialization (Dependency Injection)
    
    public init(
        transcriptionEngine: TranscriptionEngineProtocol,
        sessionManager: SessionManager = SessionManager(),
        exportService: TranscriptionExportService = TranscriptionExportService()
    ) {
        self.transcriptionEngine = transcriptionEngine
        self.sessionManager = sessionManager
        self.exportService = exportService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind transcription updates
        transcriptionEngine.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleTranscriptionUpdate(update)
            }
            .store(in: &cancellables)
        
        // Bind session manager statistics to UI
        sessionManager.$sessionDuration
            .assign(to: \.sessionDuration, on: self)
            .store(in: &cancellables)
        
        sessionManager.$wordCount
            .assign(to: \.wordCount, on: self)
            .store(in: &cancellables)
        
        sessionManager.$averageConfidence
            .assign(to: \.averageConfidence, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods (Actions)
    
    public func startTranscription() async {
        guard !isTranscribing else { return }
        
        do {
            // Clear previous error
            error = nil
            
            // Start session management
            let metadata = TranscriptionSession.Metadata()
            sessionManager.startSession(metadata: metadata)
            
            // Start transcription engine
            try await transcriptionEngine.startTranscription()
            
            // Update UI state
            isTranscribing = true
            
        } catch {
            self.error = error
            isTranscribing = false
        }
    }
    
    public func stopTranscription() async {
        guard isTranscribing else { return }
        
        // Stop transcription engine
        await transcriptionEngine.stopTranscription()
        
        // End session with final transcription
        await sessionManager.endSession(finalTranscription: transcribedText)
        
        // Update UI state
        isTranscribing = false
        currentAudioLevel = 0
    }
    
    public func pauseTranscription() async {
        guard isTranscribing else { return }
        
        await transcriptionEngine.pauseTranscription()
        sessionManager.pauseSession()
    }
    
    public func resumeTranscription() async {
        guard isTranscribing else { return }
        
        await transcriptionEngine.resumeTranscription()
        sessionManager.resumeSession()
    }
    
    public func clearTranscription() {
        transcribedText = ""
        // Note: Statistics are now managed by SessionManager
    }
    
    // MARK: - Context Management (Delegate calls)
    
    public func setContext(_ context: AppContext) async {
        await transcriptionEngine.setContext(context)
    }
    
    public func addCustomVocabulary(_ words: [String]) async {
        await transcriptionEngine.addCustomVocabulary(words)
    }
    
    // MARK: - Export Methods (Delegate to ExportService)
    
    public func exportAsText() -> String {
        guard let session = currentSession else { return transcribedText }
        return exportService.exportTranscription(session, format: .plainText)
    }
    
    public func exportAsMarkdown() -> String {
        guard let session = currentSession else {
            // Fallback for current text without session
            return generateFallbackMarkdown()
        }
        return exportService.exportTranscription(session, format: .markdown, includeTimestamps: true)
    }
    
    public func exportAs(_ format: TranscriptionExportService.ExportFormat, includeTimestamps: Bool = false) -> String {
        guard let session = currentSession else { return transcribedText }
        return exportService.exportTranscription(session, format: format, includeTimestamps: includeTimestamps)
    }
    
    public func exportAsData(_ format: TranscriptionExportService.ExportFormat, includeTimestamps: Bool = false) -> Data {
        guard let session = currentSession else { 
            return transcribedText.data(using: .utf8) ?? Data()
        }
        return exportService.exportTranscriptionData(session, format: format, includeTimestamps: includeTimestamps)
    }
    
    // MARK: - Session Access (Read-only)
    
    public func getSessionHistory() -> [TranscriptionSession] {
        return sessionManager.getSessionHistory()
    }
    
    public func getSessionStatistics() -> SessionStatistics {
        return sessionManager.getSessionStatistics()
    }
    
    // MARK: - Private Methods
    
    private func handleTranscriptionUpdate(_ update: TranscriptionUpdate) {
        switch update.type {
        case .partial:
            updatePartialTranscription(update)
            
        case .final:
            appendFinalTranscription(update)
            
        case .correction:
            applyCorrection(update)
        }
        
        // Update session with new text and confidence
        sessionManager.updateSessionTranscription(transcribedText)
        sessionManager.updateSessionConfidence(update.confidence)
        
        // Add word timings if available
        if let wordTimings = update.wordTimings {
            for timing in wordTimings {
                sessionManager.addWordTiming(timing)
            }
        }
    }
    
    private func updatePartialTranscription(_ update: TranscriptionUpdate) {
        // For partial updates, show in a different style or temporary area
        if transcribedText.isEmpty {
            transcribedText = update.text
        } else {
            // Replace last partial with new partial
            if let lastNewline = transcribedText.lastIndex(of: "\n") {
                transcribedText = String(transcribedText[..<lastNewline]) + "\n" + update.text
            } else {
                transcribedText = update.text
            }
        }
    }
    
    private func appendFinalTranscription(_ update: TranscriptionUpdate) {
        if transcribedText.isEmpty {
            transcribedText = update.text
        } else {
            transcribedText += " " + update.text
        }
    }
    
    private func applyCorrection(_ update: TranscriptionUpdate) {
        // Apply corrections to the transcribed text
        transcribedText = update.text
    }
    
    private func generateFallbackMarkdown() -> String {
        let metadata = """
        # Transcription Session
        
        **Date**: \(Date().formatted())
        **Duration**: \(formatDuration(sessionDuration))
        **Words**: \(wordCount)
        **Average Confidence**: \(Int(averageConfidence * 100))%
        
        ---
        
        ## Transcript
        
        """
        
        return metadata + transcribedText
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}