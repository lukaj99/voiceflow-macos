import Foundation
@preconcurrency import AVFoundation
import AsyncAlgorithms

/// Modern audio manager using Swift 6 actor isolation for safe audio processing
/// Separates UI state (@MainActor) from audio processing (dedicated actor)
@MainActor
public class AudioManager: ObservableObject {

    // MARK: - Published Properties
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0

    // MARK: - Private Properties
    private let audioProcessor = AudioProcessingActor()

    // MARK: - Delegate
    public weak var delegate: (any AudioManagerDelegate)?

    // MARK: - Initialization
    public init() {
        print("🎤 Modern AudioManager initialized with actor isolation")
        setupAudioStreaming()
    }

    // MARK: - Private Methods

    /// Setup audio level streaming from the processor
    private func setupAudioStreaming() {
        // Stream audio levels from the processor to UI in background task
        Task { [weak self] in
            guard let self = self else { return }
            for await level in audioProcessor.audioLevelStream {
                await MainActor.run { [weak self] in
                    self?.audioLevel = level
                }
            }
        }
    }

    // MARK: - Public Methods

    public func startRecording() async throws {
        print("🎤 Starting audio recording...")

        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }

        // Start recording via the audio processor
        try await audioProcessor.startRecording { [weak self] audioData in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.audioManager(self, didReceiveAudioData: audioData)
            }
        }

        isRecording = true
        print("✅ Audio recording started")
    }

    public func stopRecording() {
        print("🎤 Stopping audio recording...")

        guard isRecording else { return }

        Task {
            await audioProcessor.stopRecording()
        }

        isRecording = false
        audioLevel = 0.0

        print("✅ Audio recording stopped")
    }

    public func pauseRecording() {
        print("🎤 Pausing audio recording...")

        guard isRecording else { return }

        Task {
            await audioProcessor.pauseRecording()
        }

        print("⏸️ Audio recording paused")
    }

    public func resumeRecording() {
        print("🎤 Resuming audio recording...")

        Task {
            await audioProcessor.resumeRecording()
        }

        print("▶️ Audio recording resumed")
    }

}

// MARK: - Audio Processing Actor

/// Dedicated actor for audio processing, isolated from UI updates
actor AudioProcessingActor {

    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var audioFormat: AVAudioFormat?
    private nonisolated(unsafe) var targetFormat: AVAudioFormat?
    private nonisolated(unsafe) var audioConverter: AVAudioConverter?
    private var isRecording = false

    // Audio level streaming
    private let audioLevelContinuation: AsyncStream<Float>.Continuation
    public let audioLevelStream: AsyncStream<Float>

    // Audio data callback
    private var audioDataCallback: ((Data) -> Void)?

    // MARK: - Initialization

    init() {
        (audioLevelStream, audioLevelContinuation) = AsyncStream.makeStream(of: Float.self)
        print("🎤 AudioProcessingActor initialized")

        // Audio formats will be setup when starting recording
    }

    // MARK: - Public Interface

    func startRecording(audioDataCallback: @escaping @Sendable (Data) -> Void) async throws {
        guard !isRecording else {
            print("⚠️ Audio processor already recording")
            return
        }

        self.audioDataCallback = audioDataCallback

        // Setup audio formats
        await setupAudioFormats()

        // Request microphone permission
        guard await requestMicrophonePermission() else {
            throw AudioError.microphonePermissionDenied
        }

        try setupAudioEngine()
        try audioEngine.start()
        isRecording = true

        print("🎤 AudioProcessingActor started recording")
    }

    func stopRecording() async {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        audioDataCallback = nil

        // Send zero audio level
        audioLevelContinuation.yield(0.0)

        print("🎤 AudioProcessingActor stopped recording")
    }

    func pauseRecording() async {
        guard isRecording else { return }

        audioEngine.pause()
        print("🎤 AudioProcessingActor paused recording")
    }

    func resumeRecording() async {
        guard isRecording else { return }

        try? audioEngine.start()
        print("🎤 AudioProcessingActor resumed recording")
    }

    // MARK: - Private Methods

    private func setupAudioFormats() async {
        let inputNode = audioEngine.inputNode

        // Input format from microphone
        audioFormat = inputNode.outputFormat(forBus: 0)

        // Target format for Deepgram: 16kHz, 16-bit PCM, mono
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )

        // Create audio converter
        if let audioFormat = audioFormat, let targetFormat = targetFormat {
            audioConverter = AVAudioConverter(from: audioFormat, to: targetFormat)
            print("🔧 Audio converter created: \(audioFormat.sampleRate)Hz → \(targetFormat.sampleRate)Hz")
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        // macOS microphone permission is handled at system level
        print("🎤 Microphone permission assumed (macOS)")
        return true
    }

    private func setupAudioEngine() throws {
        guard let audioFormat = audioFormat else {
            throw AudioError.audioFormatNotSupported
        }

        let inputNode = audioEngine.inputNode
        let bufferSize: AVAudioFrameCount = 1024

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: audioFormat) { [weak self] buffer, _ in
            // Process buffer synchronously on real-time audio thread
            guard let self = self else { return }

            // Calculate audio level synchronously
            let level = self.calculateAudioLevel(from: buffer)

            // Convert audio synchronously
            guard let convertedBuffer = self.convertAudioFormat(buffer),
                  let audioData = self.extractPCMData(from: convertedBuffer) else {
                return
            }

            // Send processed data to actor asynchronously
            Task { [weak self] in
                await self?.handleProcessedAudio(level: level, data: audioData)
            }
        }

        print("🔧 Audio tap installed with buffer size: \(bufferSize)")
    }

    /// Handle processed audio data from the real-time thread
    private func handleProcessedAudio(level: Float, data: Data) async {
        // Stream audio level
        audioLevelContinuation.yield(level)

        // Debug: Log audio data being sent
        if !data.isEmpty {
            print("🎤 Sending \(data.count) bytes of audio data (level: \(String(format: "%.2f", level)))")
        }

        // Send audio data via callback
        audioDataCallback?(data)
    }

    nonisolated private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }

        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let decibels = 20 * log10(rms)

        // Normalize to 0-1 range (assuming -60dB to 0dB range)
        return max(0, min(1, (decibels + 60) / 60))
    }

    nonisolated private func convertAudioFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Access to these properties is safe because they're set once during initialization
        // and never modified during recording
        guard let converter = self.audioConverter,
              let targetFormat = self.targetFormat else { return nil }

        let capacityRatio = targetFormat.sampleRate / buffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * capacityRatio)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetCapacity) else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            print("❌ Audio conversion error: \(error?.localizedDescription ?? "Unknown")")
            return nil
        }

        return convertedBuffer
    }

    nonisolated private func extractPCMData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData?[0] else { return nil }

        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData, count: byteCount)
    }

    deinit {
        audioLevelContinuation.finish()
    }
}

// MARK: - Delegate Protocol

@MainActor
public protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data)
}

// MARK: - Audio Errors

public enum AudioError: Error, LocalizedError {
    case microphonePermissionDenied
    case audioFormatNotSupported
    case audioEngineStartFailed

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required"
        case .audioFormatNotSupported:
            return "Audio format not supported"
        case .audioEngineStartFailed:
            return "Failed to start audio engine"
        }
    }
}
