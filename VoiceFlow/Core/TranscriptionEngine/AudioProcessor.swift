import AVFoundation
import Combine
import os.log
import Foundation

/// Handles audio processing and performance monitoring following Single Responsibility Principle
@MainActor
public final class AudioProcessor: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let audioEngine: AudioEngineManager
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "AudioProcessor")
    
    // Performance tracking
    private var lastUpdateTime: Date = Date()
    
    // Publishers
    private let bufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    public var bufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        bufferSubject.eraseToAnyPublisher()
    }
    
    // State
    private(set) var isProcessing = false
    
    // MARK: - Initialization
    
    public init() {
        self.audioEngine = AudioEngineManager()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        audioEngine.onBufferProcessed = { [weak self] buffer in
            self?.processAudioBuffer(buffer)
        }
    }
    
    // MARK: - Public Methods
    
    public func startProcessing() async throws {
        guard !isProcessing else { return }
        
        try await audioEngine.start()
        isProcessing = true
        
        logger.info("Audio processing started")
        
        // Measure performance
        await PerformanceMonitor.shared.profileOperation("StartAudioProcessing") {
            // Track startup time
        }
    }
    
    public func stopProcessing() async {
        guard isProcessing else { return }
        
        await audioEngine.stop()
        isProcessing = false
        
        logger.info("Audio processing stopped")
    }
    
    public func pauseProcessing() async {
        // Audio engine continues running but we stop emitting buffers
        isProcessing = false
        logger.info("Audio processing paused")
    }
    
    public func resumeProcessing() async {
        isProcessing = true
        logger.info("Audio processing resumed")
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isProcessing else { return }
        
        // Measure latency
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Emit buffer for speech recognition
        bufferSubject.send(buffer)
        
        // Record latency
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        PerformanceMonitor.shared.recordLatency(latency)
        
        // Update timing
        lastUpdateTime = Date()
    }
}

// MARK: - Performance Monitoring Extension

extension AudioProcessor {
    public var currentLatency: TimeInterval {
        Date().timeIntervalSince(lastUpdateTime)
    }
    
    public func getPerformanceMetrics() -> AudioProcessingMetrics {
        AudioProcessingMetrics(
            isProcessing: isProcessing,
            lastUpdateTime: lastUpdateTime,
            currentLatency: currentLatency
        )
    }
}

// MARK: - Supporting Types

public struct AudioProcessingMetrics {
    public let isProcessing: Bool
    public let lastUpdateTime: Date
    public let currentLatency: TimeInterval
}