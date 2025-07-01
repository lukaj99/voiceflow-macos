import AVFoundation
import Combine
import Accelerate

@MainActor
public final class AudioEngineManager: ObservableObject {
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    @Published public private(set) var isRunning = false
    @Published public private(set) var isConfigured = false
    @Published public private(set) var currentAudioLevel: Float = 0
    
    // Audio configuration
    public let bufferSize: AVAudioFrameCount = 1024  // Better for speech recognition
    public let sampleRate: Double = 16000  // Optimal for speech (vs 44100 for music)
    private let audioFormat: AVAudioFormat
    
    // Publishers
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    public var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    // Callbacks
    public var onBufferProcessed: ((AVAudioPCMBuffer) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        self.audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
    }
    
    // MARK: - Public Methods
    
    public func configureAudioSession() async throws {
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setPreferredSampleRate(sampleRate)
            try audioSession.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
            try audioSession.setActive(true)
            isConfigured = true
        } catch {
            throw VoiceFlowError.audioSessionFailure(error)
        }
    }
    
    public func start() async throws {
        guard !isRunning else { return }
        
        // Auto-configure if needed
        if !isConfigured {
            try await configureAudioSession()
        }
        
        // Check microphone permission
        let permissionGranted = await checkMicrophonePermission()
        guard permissionGranted else {
            throw VoiceFlowError.microphonePermissionDenied
        }
        
        // Setup audio tap
        let inputNode = audioEngine.inputNode
        
        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)
        
        // Install new tap
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: audioFormat
        ) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                self?.processAudioBuffer(buffer)
            }
        }
        
        // Start engine
        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            throw VoiceFlowError.audioEngineFailure(error)
        }
    }
    
    public func stop() async {
        guard isRunning else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        currentAudioLevel = 0
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level
        let level = calculateAudioLevel(from: buffer)
        currentAudioLevel = level
        audioLevelSubject.send(level)
        
        // Forward buffer to callback
        onBufferProcessed?(buffer)
    }
    
    public func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        
        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square)
        var rms: Float = 0
        vDSP_rmsqv(channelDataPointer, 1, &rms, vDSP_Length(frameLength))
        
        // Convert to decibels and normalize to 0-1 range
        let avgPower = 20 * log10(rms)
        let minDb: Float = -60
        let maxDb: Float = 0
        
        let normalizedPower = (avgPower - minDb) / (maxDb - minDb)
        return max(0, min(1, normalizedPower))
    }
    
    private func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Error Types

public enum VoiceFlowError: LocalizedError {
    case microphonePermissionDenied
    case audioSessionFailure(Error)
    case audioEngineFailure(Error)
    case noAudioInput
    case speechRecognitionUnavailable
    case languageNotSupported(String)
    case transcriptionTimeout
    case lowConfidenceResult(Double)
    case insufficientMemory
    case modelLoadFailure(String)
    case storageFailure(Error)
    case syncFailure(Error)
    case authenticationFailure
    
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Please grant permission in System Settings > Privacy & Security > Microphone."
        case .audioSessionFailure(let error):
            return "Audio session failed: \(error.localizedDescription)"
        case .audioEngineFailure(let error):
            return "Audio engine failed: \(error.localizedDescription)"
        case .noAudioInput:
            return "No audio input device found."
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available. Please check your internet connection or try again later."
        case .languageNotSupported(let language):
            return "Language '\(language)' is not supported. Please select a different language in settings."
        case .transcriptionTimeout:
            return "Transcription timed out. Please try again."
        case .lowConfidenceResult(let confidence):
            return "Transcription confidence too low (\(Int(confidence * 100))%). Please speak more clearly."
        case .insufficientMemory:
            return "Insufficient memory available. Please close other applications."
        case .modelLoadFailure(let model):
            return "Failed to load speech model '\(model)'. Please restart the application."
        case .storageFailure(let error):
            return "Storage error: \(error.localizedDescription)"
        case .syncFailure(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .authenticationFailure:
            return "Authentication failed. Please sign in again."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Click here to open System Settings"
        case .insufficientMemory:
            return "Try closing other applications to free up memory"
        case .modelLoadFailure:
            return "Restart VoiceFlow to reload the speech model"
        case .speechRecognitionUnavailable:
            return "Check your internet connection and try again"
        default:
            return nil
        }
    }
}