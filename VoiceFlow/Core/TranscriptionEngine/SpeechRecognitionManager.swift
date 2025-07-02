import Speech
import AVFoundation
import Combine
import os.log
import Foundation

/// Manages core speech recognition functionality following Single Responsibility Principle
@MainActor
public final class SpeechRecognitionManager: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // State
    private(set) var isRecognizing = false
    private(set) var isPaused = false
    
    // Publishers
    private let recognitionSubject = PassthroughSubject<SFSpeechRecognitionResult?, Never>()
    public var recognitionPublisher: AnyPublisher<SFSpeechRecognitionResult?, Never> {
        recognitionSubject.eraseToAnyPublisher()
    }
    
    private let errorSubject = PassthroughSubject<Error, Never>()
    public var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "SpeechRecognitionManager")
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale.current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? 
            SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        
        super.init()
        setupSpeechRecognizer()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        speechRecognizer.delegate = self
        speechRecognizer.supportsOnDeviceRecognition = true
        speechRecognizer.defaultTaskHint = .dictation
    }
    
    // MARK: - Public Methods
    
    public func startRecognition(contextualStrings: [String]? = nil) async throws {
        guard !isRecognizing else { return }
        
        // Check authorization
        let authStatus = await requestSpeechRecognitionAuthorization()
        guard authStatus == .authorized else {
            throw VoiceFlowError.speechRecognitionUnavailable
        }
        
        // Check availability
        guard speechRecognizer.isAvailable else {
            throw VoiceFlowError.speechRecognitionUnavailable
        }
        
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
        
        // Add contextual strings if provided
        if let contextualStrings = contextualStrings, !contextualStrings.isEmpty {
            recognitionRequest.contextualStrings = contextualStrings
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        isRecognizing = true
        isPaused = false
        
        logger.info("Speech recognition started")
    }
    
    public func stopRecognition() async {
        guard isRecognizing else { return }
        
        // Stop in correct order
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        isRecognizing = false
        isPaused = false
        
        logger.info("Speech recognition stopped")
    }
    
    public func pauseRecognition() async {
        guard isRecognizing && !isPaused else { return }
        isPaused = true
        recognitionTask?.cancel()
        logger.info("Speech recognition paused")
    }
    
    public func resumeRecognition(contextualStrings: [String]? = nil) async {
        guard isRecognizing && isPaused else { return }
        isPaused = false
        
        // Restart recognition with existing setup
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation
        
        if let contextualStrings = contextualStrings, !contextualStrings.isEmpty {
            recognitionRequest.contextualStrings = contextualStrings
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        logger.info("Speech recognition resumed")
    }
    
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing && !isPaused else { return }
        recognitionRequest?.append(buffer)
    }
    
    public func updateContextualStrings(_ strings: [String]) {
        recognitionRequest?.contextualStrings = strings
    }
    
    // MARK: - Private Methods
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: (any Error)?) {
        if let error = error {
            errorSubject.send(error)
            return
        }
        
        recognitionSubject.send(result)
    }
    
    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    nonisolated public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("Speech recognizer availability changed: \(available)")
        
        if !available && isRecognizing {
            Task { @MainActor in
                await stopRecognition()
            }
        }
    }
}