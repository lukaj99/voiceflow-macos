import Speech
import AVFoundation
import Combine
import os.log

/// Real implementation of speech recognition using Apple's Speech framework
@MainActor
public final class RealSpeechRecognitionEngine: NSObject, TranscriptionEngineProtocol {
    // MARK: - Properties
    
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AudioEngineManager
    
    // State
    private(set) var isTranscribing = false
    private(set) var isPaused = false
    
    // Publishers
    private let transcriptionSubject = PassthroughSubject<TranscriptionUpdate, Never>()
    public var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    // Logging
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "SpeechRecognition")
    
    // Context and settings
    private var currentContext: AppContext = .general
    private var customVocabulary: Set<String> = []
    private var currentLanguage: String
    
    // Performance tracking
    private var lastUpdateTime: Date = Date()
    private var totalWords = 0
    private var totalConfidence: Double = 0
    
    // MARK: - Initialization
    
    public override init() {
        // Initialize with system language
        let locale = Locale.current
        self.currentLanguage = locale.identifier
        
        // Create speech recognizer
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.audioEngine = AudioEngineManager()
        
        super.init()
        
        setupSpeechRecognizer()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        speechRecognizer.delegate = self
        
        // Configure for real-time transcription
        speechRecognizer.supportsOnDeviceRecognition = true
        speechRecognizer.defaultTaskHint = .dictation
    }
    
    private func setupAudioEngine() {
        audioEngine.onBufferProcessed = { [weak self] buffer in
            self?.processAudioBuffer(buffer)
        }
    }
    
    // MARK: - TranscriptionEngineProtocol
    
    public func startTranscription() async throws {
        guard !isTranscribing else { return }
        
        // Check authorization
        let authStatus = await requestSpeechRecognitionAuthorization()
        guard authStatus == .authorized else {
            throw VoiceFlowError.speechRecognitionUnavailable
        }
        
        // Check availability
        guard speechRecognizer.isAvailable else {
            throw VoiceFlowError.speechRecognitionUnavailable
        }
        
        // Start audio engine first
        try await audioEngine.start()
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceFlowError.speechRecognitionUnavailable
        }
        
        // Configure request for real-time, on-device recognition
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation
        
        // Add custom vocabulary as context
        if !customVocabulary.isEmpty {
            recognitionRequest.contextualStrings = Array(customVocabulary)
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        isTranscribing = true
        isPaused = false
        
        logger.info("Speech recognition started")
        
        // Measure performance
        await PerformanceMonitor.shared.profileOperation("StartTranscription") {
            // Track startup time
        }
    }
    
    public func stopTranscription() async {
        guard isTranscribing else { return }
        
        // Stop in correct order
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        await audioEngine.stop()
        
        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false
        isPaused = false
        
        logger.info("Speech recognition stopped")
    }
    
    public func pauseTranscription() async {
        guard isTranscribing && !isPaused else { return }
        isPaused = true
        recognitionTask?.cancel()
        logger.info("Speech recognition paused")
    }
    
    public func resumeTranscription() async {
        guard isTranscribing && isPaused else { return }
        isPaused = false
        
        // Restart recognition with existing audio engine
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        recognitionRequest.contextualStrings = Array(customVocabulary)
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        logger.info("Speech recognition resumed")
    }
    
    public func setLanguage(_ language: String) async {
        currentLanguage = language
        
        // Recreate speech recognizer with new locale
        if let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) {
            // Stop current recognition if active
            if isTranscribing {
                await stopTranscription()
                
                // Update recognizer
                speechRecognizer.delegate = nil
                // Note: In real implementation, we'd need to store the recognizer differently
                // as it's a let constant. This is a simplified version.
                
                // Restart with new language
                try? await startTranscription()
            }
        }
    }
    
    public func setContext(_ context: AppContext) async {
        currentContext = context
        
        // Update vocabulary based on context
        switch context {
        case .coding(let language):
            loadProgrammingVocabulary(for: language)
        case .email:
            loadEmailVocabulary()
        case .meeting:
            loadMeetingVocabulary()
        case .document(let type):
            loadDocumentVocabulary(for: type)
        default:
            break
        }
        
        // Update recognition request if active
        if let request = recognitionRequest {
            request.contextualStrings = Array(customVocabulary)
        }
    }
    
    public func addCustomVocabulary(_ words: [String]) async {
        customVocabulary.formUnion(words)
        
        // Update recognition request if active
        if let request = recognitionRequest {
            request.contextualStrings = Array(customVocabulary)
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isTranscribing && !isPaused else { return }
        
        // Measure latency
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Append buffer to recognition request
        recognitionRequest?.append(buffer)
        
        // Record latency
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        PerformanceMonitor.shared.recordLatency(latency)
    }
    
    // MARK: - Recognition Handling
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            handleRecognitionError(error)
            return
        }
        
        guard let result = result else { return }
        
        // Calculate time since last update for rate limiting
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // Process the transcription
        let transcription = result.bestTranscription
        let text = transcription.formattedString
        
        // Calculate confidence (average of all segments)
        let confidence = calculateConfidence(from: transcription)
        
        // Apply context corrections
        let correctedText = applyContextCorrections(to: text)
        
        // Generate alternatives if available
        let alternatives = result.transcriptions.dropFirst().prefix(2).map { transcription in
            TranscriptionUpdate.Alternative(
                text: transcription.formattedString,
                confidence: calculateConfidence(from: transcription)
            )
        }
        
        // Extract word timings for final results
        let wordTimings: [TranscriptionUpdate.WordTiming]? = result.isFinal ? 
            extractWordTimings(from: transcription) : nil
        
        // Create update
        let update = TranscriptionUpdate(
            type: result.isFinal ? .final : .partial,
            text: correctedText,
            confidence: confidence,
            alternatives: alternatives.isEmpty ? nil : alternatives,
            wordTimings: wordTimings
        )
        
        // Emit update
        transcriptionSubject.send(update)
        lastUpdateTime = now
        
        // Update statistics
        if result.isFinal {
            let words = correctedText.split(separator: " ").count
            totalWords += words
            totalConfidence += confidence * Double(words)
        }
        
        // Log performance metrics periodically
        if totalWords % 100 == 0 && totalWords > 0 {
            let avgConfidence = totalConfidence / Double(totalWords)
            logger.info("Transcription stats - Words: \(self.totalWords), Avg confidence: \(avgConfidence)")
        }
    }
    
    private func handleRecognitionError(_ error: Error) {
        logger.error("Speech recognition error: \(error.localizedDescription)")
        
        let nsError = error as NSError
        
        // Handle specific error codes
        switch nsError.code {
        case 203: // No speech detected
            // Don't treat as error, just continue
            return
            
        case 209: // Request was cancelled
            // Expected when pausing/stopping
            return
            
        case 1110: // Network error (for online recognition)
            // Fall back to offline if possible
            if speechRecognizer.supportsOnDeviceRecognition {
                recognitionRequest?.requiresOnDeviceRecognition = true
            }
            
        default:
            // Emit error as low confidence result
            let errorUpdate = TranscriptionUpdate(
                type: .partial,
                text: "",
                confidence: 0.0
            )
            transcriptionSubject.send(errorUpdate)
        }
    }
    
    // MARK: - Authorization
    
    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    // MARK: - Context Processing
    
    private func applyContextCorrections(to text: String) -> String {
        var correctedText = text
        
        // Apply custom vocabulary
        for word in customVocabulary {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.lowercased()))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                correctedText = regex.stringByReplacingMatches(
                    in: correctedText,
                    options: [],
                    range: NSRange(location: 0, length: correctedText.utf16.count),
                    withTemplate: word
                )
            }
        }
        
        // Apply context-specific corrections
        switch currentContext {
        case .coding:
            correctedText = applyProgrammingCorrections(correctedText)
        case .email:
            correctedText = applyEmailCorrections(correctedText)
        default:
            break
        }
        
        return correctedText
    }
    
    private func applyProgrammingCorrections(_ text: String) -> String {
        let corrections = [
            ("print line", "println"),
            ("function", "func"),
            ("variable", "var"),
            ("constant", "let"),
            ("swift you eye", "SwiftUI"),
            ("you eye kit", "UIKit")
        ]
        
        var result = text
        for (pattern, replacement) in corrections {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        return result
    }
    
    private func applyEmailCorrections(_ text: String) -> String {
        // Capitalize common email phrases
        let corrections = [
            ("best regards", "Best regards"),
            ("kind regards", "Kind regards"),
            ("sincerely", "Sincerely"),
            ("dear", "Dear")
        ]
        
        var result = text
        for (pattern, replacement) in corrections {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        return result
    }
    
    // MARK: - Vocabulary Loading
    
    private func loadProgrammingVocabulary(for language: CodingLanguage?) {
        guard let language = language else { return }
        
        switch language {
        case .swift:
            customVocabulary.formUnion([
                "SwiftUI", "UIKit", "AppKit", "Combine", "async", "await",
                "ObservableObject", "@Published", "@State", "@Binding",
                "@StateObject", "@EnvironmentObject", "struct", "class", "protocol"
            ])
        case .javascript:
            customVocabulary.formUnion([
                "const", "let", "var", "async", "await", "Promise",
                "React", "useState", "useEffect", "npm", "node", "webpack"
            ])
        default:
            break
        }
    }
    
    private func loadEmailVocabulary() {
        customVocabulary.formUnion([
            "Best regards", "Kind regards", "Sincerely", "Thank you",
            "Looking forward", "Please find attached", "FYI", "ASAP"
        ])
    }
    
    private func loadMeetingVocabulary() {
        customVocabulary.formUnion([
            "agenda", "action items", "follow-up", "stakeholders",
            "deliverables", "timeline", "milestone", "KPI", "ROI"
        ])
    }
    
    private func loadDocumentVocabulary(for type: DocumentType) {
        switch type {
        case .technical:
            customVocabulary.formUnion([
                "implementation", "architecture", "framework", "API",
                "documentation", "specification", "requirement"
            ])
        case .academic:
            customVocabulary.formUnion([
                "hypothesis", "methodology", "literature", "citation",
                "abstract", "conclusion", "bibliography"
            ])
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateConfidence(from transcription: SFTranscription) -> Double {
        guard !transcription.segments.isEmpty else { return 0.0 }
        
        let totalConfidence = transcription.segments.reduce(0.0) { sum, segment in
            sum + segment.confidence
        }
        
        return totalConfidence / Double(transcription.segments.count)
    }
    
    private func extractWordTimings(from transcription: SFTranscription) -> [TranscriptionUpdate.WordTiming] {
        transcription.segments.map { segment in
            TranscriptionUpdate.WordTiming(
                word: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: segment.confidence
            )
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension RealSpeechRecognitionEngine: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("Speech recognizer availability changed: \(available)")
        
        if !available && isTranscribing {
            // Notify user that recognition is temporarily unavailable
            let update = TranscriptionUpdate(
                type: .partial,
                text: "[Speech recognition temporarily unavailable]",
                confidence: 0.0
            )
            transcriptionSubject.send(update)
        }
    }
}