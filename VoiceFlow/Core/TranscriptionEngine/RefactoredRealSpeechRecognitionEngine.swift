import Speech
import AVFoundation
import Combine
import os.log
import Foundation

/// Real implementation of speech recognition using Apple's Speech framework
/// Refactored to use composition and follow SOLID principles
@MainActor
public final class RefactoredRealSpeechRecognitionEngine: NSObject, TranscriptionEngineProtocol, @unchecked Sendable {
    // MARK: - Properties
    
    // Composed services following Single Responsibility Principle
    private let speechRecognitionManager: SpeechRecognitionManager
    private let audioProcessor: AudioProcessor
    private let contextProcessor: ContextProcessor
    private let errorHandler: SpeechErrorHandler
    private let transcriptionProcessor: TranscriptionProcessor
    
    // State
    private(set) var isTranscribing = false
    private(set) var isPaused = false
    private var currentLanguage: String
    
    // Publishers
    public var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> {
        transcriptionProcessor.transcriptionPublisher
    }
    
    // Logging
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "SpeechRecognition")
    
    // Storage for cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public override init() {
        // Initialize with system language
        let locale = Locale.current
        self.currentLanguage = locale.identifier
        
        // Initialize composed services
        self.speechRecognitionManager = SpeechRecognitionManager(locale: locale)
        self.audioProcessor = AudioProcessor()
        self.contextProcessor = ContextProcessor()
        self.errorHandler = SpeechErrorHandler()
        self.transcriptionProcessor = TranscriptionProcessor(contextProcessor: contextProcessor)
        
        super.init()
        
        setupServiceBindings()
    }
    
    // MARK: - Setup
    
    private func setupServiceBindings() {
        // Connect audio processor to speech recognition manager
        audioProcessor.bufferPublisher
            .sink { [weak self] buffer in
                self?.speechRecognitionManager.processAudioBuffer(buffer)
            }
            .store(in: &cancellables)
        
        // Connect speech recognition results to transcription processor
        speechRecognitionManager.recognitionPublisher
            .compactMap { $0 } // Filter out nil results
            .sink { [weak self] result in
                self?.transcriptionProcessor.processRecognitionResult(result)
            }
            .store(in: &cancellables)
        
        // Connect error handling
        speechRecognitionManager.errorPublisher
            .sink { [weak self] error in
                guard let self = self else { return }
                let features = SpeechFeatures(supportsOnDeviceRecognition: true)
                self.errorHandler.handleError(error, supportedFeatures: features)
            }
            .store(in: &cancellables)
        
        // Handle error recovery actions
        errorHandler.recoveryActionPublisher
            .sink { [weak self] action in
                self?.handleRecoveryAction(action)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - TranscriptionEngineProtocol Implementation
    
    public func startTranscription() async throws {
        guard !isTranscribing else { return }
        
        logger.info("Starting transcription with refactored engine")
        
        // Start audio processing
        try await audioProcessor.startProcessing()
        
        // Start speech recognition with current context
        let contextualStrings = contextProcessor.getContextualStrings()
        try await speechRecognitionManager.startRecognition(contextualStrings: contextualStrings)
        
        // Update state
        isTranscribing = true
        isPaused = false
        
        // Measure performance
        await PerformanceMonitor.shared.profileOperation("StartTranscription") {
            // Track startup time
        }
        
        logger.info("Transcription started successfully")
    }
    
    public func stopTranscription() async {
        guard isTranscribing else { return }
        
        logger.info("Stopping transcription")
        
        // Stop services in correct order
        await speechRecognitionManager.stopRecognition()
        await audioProcessor.stopProcessing()
        
        // Update state
        isTranscribing = false
        isPaused = false
        
        logger.info("Transcription stopped")
    }
    
    public func pauseTranscription() async {
        guard isTranscribing && !isPaused else { return }
        
        logger.info("Pausing transcription")
        
        // Pause services
        await speechRecognitionManager.pauseRecognition()
        await audioProcessor.pauseProcessing()
        
        isPaused = true
    }
    
    public func resumeTranscription() async {
        guard isTranscribing && isPaused else { return }
        
        logger.info("Resuming transcription")
        
        // Resume services
        await audioProcessor.resumeProcessing()
        
        let contextualStrings = contextProcessor.getContextualStrings()
        await speechRecognitionManager.resumeRecognition(contextualStrings: contextualStrings)
        
        isPaused = false
    }
    
    public func setLanguage(_ language: String) async {
        currentLanguage = language
        
        logger.info("Language change requested to: \(language)")
        
        // For language changes, we need to recreate the speech recognition manager
        // This is a limitation of the current implementation that could be improved
        if isTranscribing {
            await stopTranscription()
            
            // TODO: Recreate speechRecognitionManager with new locale
            // This would require dependency injection to make it more flexible
            
            try? await startTranscription()
        }
    }
    
    public func setContext(_ context: AppContext) async {
        logger.info("Setting context: \(String(describing: context))")
        
        // Delegate to context processor
        contextProcessor.setContext(context)
        
        // Update recognition with new contextual strings
        let contextualStrings = contextProcessor.getContextualStrings()
        speechRecognitionManager.updateContextualStrings(contextualStrings)
    }
    
    public func addCustomVocabulary(_ words: [String]) async {
        logger.debug("Adding \(words.count) custom vocabulary words")
        
        // Delegate to context processor
        contextProcessor.addCustomVocabulary(words)
        
        // Update recognition with new contextual strings
        let contextualStrings = contextProcessor.getContextualStrings()
        speechRecognitionManager.updateContextualStrings(contextualStrings)
    }
    
    // MARK: - Private Methods
    
    private func handleRecoveryAction(_ action: ErrorRecoveryAction) {
        logger.info("Handling recovery action: \(action)")
        
        Task {
            switch action {
            case .none:
                break
                
            case .retryAfterDelay(let delay):
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if isTranscribing {
                    try? await startTranscription()
                }
                
            case .fallbackToOffline:
                // This would require updating the speech recognition manager
                // to force offline recognition
                logger.info("Falling back to offline recognition")
                
            case .requestPermissions:
                logger.warning("Permissions required - user intervention needed")
                
            case .restart:
                if isTranscribing {
                    await stopTranscription()
                    try? await startTranscription()
                }
            }
        }
    }
    
    // MARK: - Public Utilities
    
    public func getTranscriptionStatistics() -> TranscriptionStatistics {
        return transcriptionProcessor.getStatistics()
    }
    
    public func resetStatistics() {
        transcriptionProcessor.resetStatistics()
    }
    
    public func getAudioProcessingMetrics() -> AudioProcessingMetrics {
        return audioProcessor.getPerformanceMetrics()
    }
}