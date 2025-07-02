import Foundation
import Combine
import SwiftUI

@MainActor
public class TranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var transcribedText = ""
    @Published public var isTranscribing = false
    @Published public var currentAudioLevel: Float = 0
    @Published public var error: Error?
    @Published public var currentSession: TranscriptionSession?
    
    // MARK: - Private Properties
    
    private var transcriptionEngine: RealSpeechRecognitionEngine?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Statistics
    
    @Published public var sessionDuration: TimeInterval = 0
    @Published public var wordCount: Int = 0
    @Published public var averageConfidence: Double = 0
    
    private var sessionStartTime: Date?
    private var sessionTimerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init() {
        setupEngines()
    }
    
    // MARK: - Setup
    
    private func setupEngines() {
        Task {
            await initializeEngines()
        }
    }
    
    private func initializeEngines() async {
        // Initialize transcription engine (which includes audio engine)
        transcriptionEngine = RealSpeechRecognitionEngine()
        
        // Setup bindings
        setupBindings()
    }
    
    private func setupBindings() {
        // Transcription updates
        transcriptionEngine?.transcriptionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptionUpdate(update)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func startTranscription() async {
        guard !isTranscribing else { return }
        
        do {
            // Clear previous error
            error = nil
            
            // Start session
            sessionStartTime = Date()
            startSessionTimer()
            
            // Start engines
            try await transcriptionEngine?.startTranscription()
            
            // Update state
            isTranscribing = true
            
            // Create new session
            currentSession = TranscriptionSession(
                startTime: sessionStartTime ?? Date(),
                metadata: TranscriptionSession.Metadata()
            )
        } catch {
            self.error = error
            isTranscribing = false
        }
    }
    
    public func stopTranscription() async {
        guard isTranscribing else { return }
        
        // Stop engines
        await transcriptionEngine?.stopTranscription()
        
        // Update state
        isTranscribing = false
        currentAudioLevel = 0
        
        // Stop timer
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
        
        // Finalize session
        if var session = currentSession {
            session.endTime = Date()
            session.duration = sessionDuration
            session.wordCount = wordCount
            session.averageConfidence = averageConfidence
            session.transcription = transcribedText
            currentSession = session
            
            // Save session (to be implemented)
            await saveSession(session)
        }
    }
    
    public func pauseTranscription() async {
        await transcriptionEngine?.pauseTranscription()
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
    }
    
    public func resumeTranscription() async {
        await transcriptionEngine?.resumeTranscription()
        startSessionTimer()
    }
    
    public func clearTranscription() {
        transcribedText = ""
        wordCount = 0
        averageConfidence = 0
        sessionDuration = 0
        currentSession = nil
    }
    
    // MARK: - Context Management
    
    public func setContext(_ context: AppContext) async {
        await transcriptionEngine?.setContext(context)
    }
    
    public func addCustomVocabulary(_ words: [String]) async {
        await transcriptionEngine?.addCustomVocabulary(words)
    }
    
    // MARK: - Private Methods
    
    private func handleTranscriptionUpdate(_ update: TranscriptionUpdate) {
        switch update.type {
        case .partial:
            // Update UI with partial results
            updatePartialTranscription(update)
            
        case .final:
            // Append final results
            appendFinalTranscription(update)
            
        case .correction:
            // Apply corrections
            applyCorrection(update)
        }
        
        // Update statistics
        updateStatistics(from: update)
    }
    
    private func updatePartialTranscription(_ update: TranscriptionUpdate) {
        // For partial updates, show in a different style or temporary area
        // This is a simplified implementation
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
        
        // Update word count
        wordCount = transcribedText.split(separator: " ").count
    }
    
    private func applyCorrection(_ update: TranscriptionUpdate) {
        // Apply corrections to the transcribed text
        // This would be more sophisticated in production
        transcribedText = update.text
    }
    
    private func updateStatistics(from update: TranscriptionUpdate) {
        // Update average confidence
        if averageConfidence == 0 {
            averageConfidence = update.confidence
        } else {
            // Running average
            let updateCount = Double(wordCount + 1)
            averageConfidence = (averageConfidence * Double(wordCount) + update.confidence) / updateCount
        }
    }
    
    private func startSessionTimer() {
        sessionTimerTask = Task {
            while !Task.isCancelled, let startTime = sessionStartTime {
                await updateSessionDuration(from: startTime)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func updateSessionDuration(from startTime: Date) async {
        sessionDuration = Date().timeIntervalSince(startTime)
    }
    
    private func saveSession(_ session: TranscriptionSession) async {
        // TODO: Implement session storage
        print("Saving session: \(session.id)")
    }
}

// MARK: - Export Functions

extension TranscriptionViewModel {
    public func exportAsText() -> String {
        return transcribedText
    }
    
    public func exportAsMarkdown() -> String {
        let metadata = """
        # Transcription Session
        
        **Date**: \(sessionStartTime?.formatted() ?? "Unknown")
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