//
//  MockTranscriptionEngine.swift
//  VoiceFlowTests
//
//  Mock implementation of transcription engine for integrated testing
//

import Foundation
@testable import VoiceFlow

/// Mock transcription engine for testing complete transcription flows
public final actor MockTranscriptionEngine: Sendable {
    
    // MARK: - Properties
    
    /// Current engine state
    private var state: EngineState = .idle
    
    /// Active transcription session
    private var activeSession: TranscriptionSession?
    
    /// Completed sessions
    private var completedSessions: [TranscriptionSession] = []
    
    /// Mock speech recognizer
    private let speechRecognizer: MockSpeechRecognizer
    
    /// Mock audio engine
    private let audioEngine: MockAudioEngine
    
    /// Progress handler
    private var progressHandler: ((TranscriptionProgress) -> Void)?
    
    /// Error handler
    private var errorHandler: ((Error) -> Void)?
    
    /// Configuration
    private var configuration = EngineConfiguration()
    
    /// Performance metrics
    private var metrics = PerformanceMetrics()
    
    // MARK: - Types
    
    public enum EngineState: Sendable {
        case idle
        case preparing
        case recording
        case processing
        case paused
        case error(Error)
    }
    
    public struct EngineConfiguration: Sendable {
        public var language: String = "en-US"
        public var continuous: Bool = false
        public var autoSave: Bool = true
        public var maxDuration: TimeInterval = 300 // 5 minutes
        public var bufferSize: Int = 1024
        public var enableMetrics: Bool = true
    }
    
    public struct TranscriptionProgress: Sendable {
        public let session: TranscriptionSession
        public let currentText: String
        public let duration: TimeInterval
        public let audioLevel: Float
        public let isProcessing: Bool
    }
    
    public struct PerformanceMetrics: Sendable {
        public var startupTime: TimeInterval = 0
        public var processingLatency: TimeInterval = 0
        public var totalTranscriptions: Int = 0
        public var averageConfidence: Float = 0
        public var errorCount: Int = 0
    }
    
    public enum MockError: LocalizedError, Sendable {
        case engineBusy
        case noActiveSession
        case configurationError(String)
        case transcriptionTimeout
        
        public var errorDescription: String? {
            switch self {
            case .engineBusy:
                return "Transcription engine is busy"
            case .noActiveSession:
                return "No active transcription session"
            case .configurationError(let message):
                return "Configuration error: \(message)"
            case .transcriptionTimeout:
                return "Transcription timed out"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(
        speechRecognizer: MockSpeechRecognizer? = nil,
        audioEngine: MockAudioEngine? = nil
    ) {
        self.speechRecognizer = speechRecognizer ?? MockSpeechRecognizer()
        self.audioEngine = audioEngine ?? MockAudioEngine()
    }
    
    // MARK: - Configuration
    
    public func configure(_ configuration: EngineConfiguration) {
        self.configuration = configuration
    }
    
    public func setProgressHandler(_ handler: @escaping (TranscriptionProgress) -> Void) {
        self.progressHandler = handler
    }
    
    public func setErrorHandler(_ handler: @escaping (Error) -> Void) {
        self.errorHandler = handler
    }
    
    // MARK: - Transcription Control
    
    public func startTranscription() async throws -> TranscriptionSession {
        let startTime = Date()
        
        guard state == .idle else {
            throw MockError.engineBusy
        }
        
        state = .preparing
        
        // Start audio engine
        try await audioEngine.start()
        
        // Create session
        let session = TranscriptionSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            transcription: "",
            segments: [],
            metadata: SessionMetadata(
                language: configuration.language,
                audioQuality: "high",
                deviceInfo: "Mock Device"
            )
        )
        
        activeSession = session
        state = .recording
        
        // Start recording
        try await audioEngine.startRecording()
        
        // Start recognition
        let recognitionTask = try await speechRecognizer.startRecognition()
        
        // Update metrics
        if configuration.enableMetrics {
            metrics.startupTime = Date().timeIntervalSince(startTime)
            metrics.totalTranscriptions += 1
        }
        
        // Process recognition results
        Task {
            await processRecognitionResults(task: recognitionTask, session: session)
        }
        
        return session
    }
    
    public func stopTranscription() async throws -> TranscriptionSession {
        guard let session = activeSession else {
            throw MockError.noActiveSession
        }
        
        guard state == .recording || state == .paused else {
            throw MockError.noActiveSession
        }
        
        state = .processing
        
        // Stop recording
        await audioEngine.stopRecording()
        await audioEngine.stop()
        
        // Stop recognition
        await speechRecognizer.stopAllTasks()
        
        // Finalize session
        var finalSession = session
        finalSession.endTime = Date()
        
        completedSessions.append(finalSession)
        activeSession = nil
        state = .idle
        
        return finalSession
    }
    
    public func pauseTranscription() async throws {
        guard activeSession != nil else {
            throw MockError.noActiveSession
        }
        
        guard state == .recording else {
            return
        }
        
        state = .paused
        await audioEngine.pause()
    }
    
    public func resumeTranscription() async throws {
        guard activeSession != nil else {
            throw MockError.noActiveSession
        }
        
        guard state == .paused else {
            return
        }
        
        state = .recording
        try await audioEngine.resume()
    }
    
    // MARK: - Processing
    
    private func processRecognitionResults(
        task: MockSpeechRecognizer.MockRecognitionTask,
        session: TranscriptionSession
    ) async {
        while state == .recording || state == .paused {
            // Get current audio level
            let audioLevel = await audioEngine.getCurrentAudioLevel()
            
            // Check for new results
            if let latestResult = task.results.last {
                var updatedSession = session
                updatedSession.transcription = latestResult.transcription
                
                // Update segments
                updatedSession.segments = latestResult.segments.map { segment in
                    TranscriptionSegment(
                        text: segment.text,
                        startTime: segment.timestamp,
                        endTime: segment.timestamp + segment.duration,
                        confidence: segment.confidence
                    )
                }
                
                // Update confidence metrics
                if configuration.enableMetrics {
                    let totalConfidence = updatedSession.segments.reduce(0) { $0 + $1.confidence }
                    metrics.averageConfidence = totalConfidence / Float(max(1, updatedSession.segments.count))
                }
                
                activeSession = updatedSession
                
                // Send progress update
                let progress = TranscriptionProgress(
                    session: updatedSession,
                    currentText: latestResult.transcription,
                    duration: Date().timeIntervalSince(session.startTime),
                    audioLevel: audioLevel,
                    isProcessing: !latestResult.isFinal
                )
                
                progressHandler?(progress)
                
                if latestResult.isFinal {
                    break
                }
            }
            
            // Small delay to prevent tight loop
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    // MARK: - Query Methods
    
    public func getState() -> EngineState {
        return state
    }
    
    public func getActiveSession() -> TranscriptionSession? {
        return activeSession
    }
    
    public func getCompletedSessions() -> [TranscriptionSession] {
        return completedSessions
    }
    
    public func getMetrics() -> PerformanceMetrics {
        return metrics
    }
    
    public func isRecording() -> Bool {
        return state == .recording
    }
    
    // MARK: - Test Helpers
    
    public func simulateCompleteTranscription(
        text: String,
        duration: TimeInterval = 5.0
    ) async throws -> TranscriptionSession {
        // Queue results in speech recognizer
        let words = text.split(separator: " ")
        var results: [MockSpeechRecognizer.MockRecognitionResult] = []
        
        for (index, word) in words.enumerated() {
            let accumulatedText = words[0...index].joined(separator: " ")
            results.append(
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: accumulatedText,
                    confidence: 0.9 + Float(index) * 0.01,
                    isFinal: index == words.count - 1
                )
            )
        }
        
        await speechRecognizer.queueResults(results)
        
        // Start transcription
        let session = try await startTranscription()
        
        // Wait for completion
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        // Stop and return
        return try await stopTranscription()
    }
    
    public func reset() async {
        state = .idle
        activeSession = nil
        completedSessions.removeAll()
        metrics = PerformanceMetrics()
        await audioEngine.stop()
        await speechRecognizer.stopAllTasks()
    }
}

// MARK: - Test Factory

public struct MockTranscriptionEngineFactory {
    
    public static func createDefault() -> MockTranscriptionEngine {
        return MockTranscriptionEngine()
    }
    
    public static func createConfigured(
        language: String = "en-US",
        continuous: Bool = false
    ) async -> MockTranscriptionEngine {
        let engine = createDefault()
        
        await engine.configure(
            MockTranscriptionEngine.EngineConfiguration(
                language: language,
                continuous: continuous,
                autoSave: true,
                maxDuration: 300,
                bufferSize: 1024,
                enableMetrics: true
            )
        )
        
        return engine
    }
    
    public static func createWithPresetResults() async -> MockTranscriptionEngine {
        let speechRecognizer = MockSpeechRecognizerFactory.createWithSampleResults()
        let audioEngine = await MockAudioEngineFactory.createDefaultEngine()
        
        return MockTranscriptionEngine(
            speechRecognizer: speechRecognizer,
            audioEngine: audioEngine
        )
    }
}