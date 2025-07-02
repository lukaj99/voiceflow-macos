//
//  MockSpeechRecognizer.swift
//  VoiceFlowTests
//
//  Mock implementation of speech recognition for testing
//

import Foundation
import Speech
import AVFoundation

/// Thread-safe mock speech recognizer for testing
public final actor MockSpeechRecognizer: Sendable {
    // MARK: - Properties
    
    /// Simulated authorization status
    private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// Simulated availability
    private var isAvailable: Bool = true
    
    /// Simulated locale
    private var locale: Locale = Locale.current
    
    /// Queue of results to return for recognition tasks
    private var queuedResults: [MockRecognitionResult] = []
    
    /// Current active tasks
    private var activeTasks: [UUID: MockRecognitionTask] = [:]
    
    /// Error to throw on next operation
    private var nextError: Error?
    
    /// Delay for simulating async operations
    private var simulationDelay: TimeInterval = 0.1
    
    /// Recognition progress callback
    private var progressHandler: ((MockRecognitionResult) -> Void)?
    
    // MARK: - Mock Data Types
    
    public struct MockRecognitionResult: Sendable {
        public let transcription: String
        public let confidence: Float
        public let segments: [TranscriptionSegment]
        public let isFinal: Bool
        public let timestamp: TimeInterval
        
        public init(
            transcription: String,
            confidence: Float = 0.95,
            segments: [TranscriptionSegment] = [],
            isFinal: Bool = false,
            timestamp: TimeInterval = Date().timeIntervalSince1970
        ) {
            self.transcription = transcription
            self.confidence = confidence
            self.segments = segments.isEmpty ? [TranscriptionSegment(text: transcription, confidence: confidence, timestamp: timestamp)] : segments
            self.isFinal = isFinal
            self.timestamp = timestamp
        }
    }
    
    public struct TranscriptionSegment: Sendable {
        public let text: String
        public let confidence: Float
        public let timestamp: TimeInterval
        public let duration: TimeInterval
        
        public init(
            text: String,
            confidence: Float = 0.95,
            timestamp: TimeInterval = Date().timeIntervalSince1970,
            duration: TimeInterval = 1.0
        ) {
            self.text = text
            self.confidence = confidence
            self.timestamp = timestamp
            self.duration = duration
        }
    }
    
    public final class MockRecognitionTask: Sendable {
        public let id = UUID()
        public private(set) var state: State = .idle
        public private(set) var results: [MockRecognitionResult] = []
        
        public enum State: Sendable {
            case idle
            case running
            case completed
            case cancelled
            case failed(Error)
        }
        
        public func cancel() {
            state = .cancelled
        }
        
        fileprivate func updateState(_ newState: State) {
            state = newState
        }
        
        fileprivate func addResult(_ result: MockRecognitionResult) {
            results.append(result)
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration Methods
    
    public func setAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) {
        self.authorizationStatus = status
    }
    
    public func setAvailability(_ available: Bool) {
        self.isAvailable = available
    }
    
    public func setLocale(_ locale: Locale) {
        self.locale = locale
    }
    
    public func queueResult(_ result: MockRecognitionResult) {
        queuedResults.append(result)
    }
    
    public func queueResults(_ results: [MockRecognitionResult]) {
        queuedResults.append(contentsOf: results)
    }
    
    public func clearQueuedResults() {
        queuedResults.removeAll()
    }
    
    public func setNextError(_ error: Error?) {
        self.nextError = error
    }
    
    public func setSimulationDelay(_ delay: TimeInterval) {
        self.simulationDelay = delay
    }
    
    public func setProgressHandler(_ handler: @escaping (MockRecognitionResult) -> Void) {
        self.progressHandler = handler
    }
    
    // MARK: - Mock Recognition Methods
    
    public func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        // Simulate async authorization
        try? await Task.sleep(nanoseconds: UInt64(simulationDelay * 1_000_000_000))
        
        if authorizationStatus == .notDetermined {
            authorizationStatus = .authorized
        }
        
        return authorizationStatus
    }
    
    public func startRecognition(audioURL: URL? = nil) async throws -> MockRecognitionTask {
        // Check for errors
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        // Check authorization
        guard authorizationStatus == .authorized else {
            throw MockError.notAuthorized
        }
        
        // Check availability
        guard isAvailable else {
            throw MockError.notAvailable
        }
        
        // Create task
        let task = MockRecognitionTask()
        activeTasks[task.id] = task
        task.updateState(.running)
        
        // Process queued results
        Task {
            for result in queuedResults {
                guard task.state == .running else { break }
                
                try? await Task.sleep(nanoseconds: UInt64(simulationDelay * 1_000_000_000))
                
                task.addResult(result)
                progressHandler?(result)
                
                if result.isFinal {
                    task.updateState(.completed)
                    activeTasks[task.id] = nil
                    break
                }
            }
            
            if task.state == .running {
                task.updateState(.completed)
                activeTasks[task.id] = nil
            }
        }
        
        return task
    }
    
    public func stopAllTasks() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    // MARK: - Test Helpers
    
    public func simulateRealTimeTranscription(
        phrases: [String],
        intervalSeconds: TimeInterval = 0.5
    ) async {
        var accumulatedText = ""
        
        for (index, phrase) in phrases.enumerated() {
            accumulatedText += (accumulatedText.isEmpty ? "" : " ") + phrase
            
            let result = MockRecognitionResult(
                transcription: accumulatedText,
                confidence: 0.85 + Float(index) * 0.03,
                isFinal: index == phrases.count - 1
            )
            
            queueResult(result)
            
            if index < phrases.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            }
        }
    }
    
    public func getActiveTaskCount() -> Int {
        return activeTasks.count
    }
    
    public func getAllTasks() -> [MockRecognitionTask] {
        return Array(activeTasks.values)
    }
    
    // MARK: - Error Types
    
    public enum MockError: LocalizedError, Sendable {
        case notAuthorized
        case notAvailable
        case recognitionFailed
        case audioError
        case networkError
        
        public var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized"
            case .notAvailable:
                return "Speech recognition not available"
            case .recognitionFailed:
                return "Recognition failed"
            case .audioError:
                return "Audio processing error"
            case .networkError:
                return "Network error during recognition"
            }
        }
    }
}

// MARK: - Test Data Factory

public struct MockSpeechRecognizerFactory {
    public static func createDefaultRecognizer() -> MockSpeechRecognizer {
        let recognizer = MockSpeechRecognizer()
        Task {
            await recognizer.setAuthorizationStatus(.authorized)
            await recognizer.setAvailability(true)
        }
        return recognizer
    }
    
    public static func createUnauthorizedRecognizer() -> MockSpeechRecognizer {
        let recognizer = MockSpeechRecognizer()
        Task {
            await recognizer.setAuthorizationStatus(.denied)
        }
        return recognizer
    }
    
    public static func createUnavailableRecognizer() -> MockSpeechRecognizer {
        let recognizer = MockSpeechRecognizer()
        Task {
            await recognizer.setAuthorizationStatus(.authorized)
            await recognizer.setAvailability(false)
        }
        return recognizer
    }
    
    public static func createWithSampleResults() -> MockSpeechRecognizer {
        let recognizer = createDefaultRecognizer()
        
        Task {
            await recognizer.queueResults([
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: "Hello",
                    confidence: 0.85,
                    isFinal: false
                ),
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: "Hello world",
                    confidence: 0.90,
                    isFinal: false
                ),
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: "Hello world, this is a test",
                    confidence: 0.95,
                    isFinal: true
                )
            ])
        }
        
        return recognizer
    }
}