//
//  MockAudioEngine.swift
//  VoiceFlowTests
//
//  Mock implementation of audio engine for testing
//

import Foundation
import AVFoundation

/// Thread-safe mock audio engine for testing audio functionality
public final actor MockAudioEngine: Sendable {
    // MARK: - Properties
    
    /// Current engine state
    private var isRunning: Bool = false
    
    /// Simulated audio format
    private var format: AVAudioFormat
    
    /// Buffer queue for simulated audio
    private var audioBufferQueue: [AVAudioPCMBuffer] = []
    
    /// Recording state
    private var isRecording: Bool = false
    
    /// Error to throw on next operation
    private var nextError: Error?
    
    /// Audio level simulation
    private var simulatedAudioLevel: Float = 0.0
    
    /// Audio interruption handler
    private var interruptionHandler: ((InterruptionType) -> Void)?
    
    /// Buffer processing handler
    private var bufferHandler: ((AVAudioPCMBuffer) -> Void)?
    
    /// Performance metrics
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Types
    
    public enum InterruptionType: Sendable {
        case began
        case ended
    }
    
    public struct PerformanceMetrics: Sendable {
        public var bufferUnderruns: Int = 0
        public var processingLatency: TimeInterval = 0.0
        public var cpuUsage: Float = 0.0
        public var memoryUsage: Float = 0.0
    }
    
    public enum MockError: LocalizedError, Sendable {
        case engineNotRunning
        case engineAlreadyRunning
        case recordingInProgress
        case noAudioInput
        case bufferAllocationFailed
        case hardwareError
        
        public var errorDescription: String? {
            switch self {
            case .engineNotRunning:
                return "Audio engine is not running"
            case .engineAlreadyRunning:
                return "Audio engine is already running"
            case .recordingInProgress:
                return "Recording is already in progress"
            case .noAudioInput:
                return "No audio input available"
            case .bufferAllocationFailed:
                return "Failed to allocate audio buffer"
            case .hardwareError:
                return "Hardware error occurred"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        // Create default format: 44.1kHz, mono
        self.format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
    }
    
    // MARK: - Configuration Methods
    
    public func setFormat(_ format: AVAudioFormat) {
        self.format = format
    }
    
    public func setNextError(_ error: Error?) {
        self.nextError = error
    }
    
    public func setSimulatedAudioLevel(_ level: Float) {
        self.simulatedAudioLevel = max(0.0, min(1.0, level))
    }
    
    public func setInterruptionHandler(_ handler: @escaping (InterruptionType) -> Void) {
        self.interruptionHandler = handler
    }
    
    public func setBufferHandler(_ handler: @escaping (AVAudioPCMBuffer) -> Void) {
        self.bufferHandler = handler
    }
    
    public func updatePerformanceMetrics(_ update: (inout PerformanceMetrics) -> Void) {
        update(&performanceMetrics)
    }
    
    // MARK: - Engine Control
    
    public func start() async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        guard !isRunning else {
            throw MockError.engineAlreadyRunning
        }
        
        isRunning = true
        
        // Simulate engine startup
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    public func stop() async {
        guard isRunning else { return }
        
        isRunning = false
        isRecording = false
        audioBufferQueue.removeAll()
        
        // Simulate engine shutdown
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
    }
    
    public func pause() async {
        guard isRunning else { return }
        isRecording = false
    }
    
    public func resume() async throws {
        guard isRunning else {
            throw MockError.engineNotRunning
        }
        isRecording = true
    }
    
    // MARK: - Recording Control
    
    public func startRecording() async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        guard isRunning else {
            throw MockError.engineNotRunning
        }
        
        guard !isRecording else {
            throw MockError.recordingInProgress
        }
        
        isRecording = true
        
        // Start buffer simulation
        Task {
            await simulateAudioBuffers()
        }
    }
    
    public func stopRecording() async {
        isRecording = false
    }
    
    // MARK: - Audio Simulation
    
    private func simulateAudioBuffers() async {
        while isRecording {
            // Create simulated audio buffer
            if let buffer = createSimulatedBuffer() {
                audioBufferQueue.append(buffer)
                bufferHandler?(buffer)
            }
            
            // Simulate buffer interval (10ms)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    
    private func createSimulatedBuffer() -> AVAudioPCMBuffer? {
        let frameCapacity: AVAudioFrameCount = 441 // 10ms at 44.1kHz
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCapacity
        ) else {
            return nil
        }
        
        buffer.frameLength = frameCapacity
        
        // Fill buffer with simulated audio data
        if let channelData = buffer.floatChannelData {
            let amplitude = simulatedAudioLevel
            
            for frame in 0..<Int(frameCapacity) {
                // Generate simple sine wave with noise
                let time = Float(frame) / Float(format.sampleRate)
                let frequency: Float = 440.0 // A4 note
                let sineWave = amplitude * sin(2.0 * .pi * frequency * time)
                let noise = (Float.random(in: -0.1...0.1) * amplitude * 0.1)
                
                channelData[0][frame] = sineWave + noise
            }
        }
        
        return buffer
    }
    
    // MARK: - State Query
    
    public func getIsRunning() -> Bool {
        return isRunning
    }
    
    public func getIsRecording() -> Bool {
        return isRecording
    }
    
    public func getFormat() -> AVAudioFormat {
        return format
    }
    
    public func getCurrentAudioLevel() -> Float {
        return isRecording ? simulatedAudioLevel : 0.0
    }
    
    public func getPerformanceMetrics() -> PerformanceMetrics {
        return performanceMetrics
    }
    
    // MARK: - Buffer Management
    
    public func getQueuedBufferCount() -> Int {
        return audioBufferQueue.count
    }
    
    public func clearBufferQueue() {
        audioBufferQueue.removeAll()
    }
    
    public func injectBuffer(_ buffer: AVAudioPCMBuffer) {
        audioBufferQueue.append(buffer)
        if isRecording {
            bufferHandler?(buffer)
        }
    }
    
    // MARK: - Interruption Simulation
    
    public func simulateInterruption(_ type: InterruptionType) {
        interruptionHandler?(type)
        
        switch type {
        case .began:
            isRecording = false
        case .ended:
            // Recording can be resumed manually
            break
        }
    }
    
    // MARK: - Test Helpers
    
    public func simulateRecording(duration: TimeInterval) async {
        guard isRunning else { return }
        
        try? await startRecording()
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        await stopRecording()
    }
    
    public func simulateAudioLevelChanges(
        levels: [Float],
        intervalSeconds: TimeInterval = 0.1
    ) async {
        for level in levels {
            setSimulatedAudioLevel(level)
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
    }
}

// MARK: - Test Data Factory

public struct MockAudioEngineFactory {
    public static func createDefaultEngine() async -> MockAudioEngine {
        let engine = MockAudioEngine()
        await engine.setSimulatedAudioLevel(0.5)
        return engine
    }
    
    public static func createRunningEngine() async throws -> MockAudioEngine {
        let engine = await createDefaultEngine()
        try await engine.start()
        return engine
    }
    
    public static func createRecordingEngine() async throws -> MockAudioEngine {
        let engine = try await createRunningEngine()
        try await engine.startRecording()
        return engine
    }
    
    public static func createFailingEngine() async -> MockAudioEngine {
        let engine = MockAudioEngine()
        await engine.setNextError(MockAudioEngine.MockError.hardwareError)
        return engine
    }
    
    public static func createHighPerformanceEngine() async -> MockAudioEngine {
        let engine = MockAudioEngine()
        
        // Configure for high-quality audio
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        )!
        
        await engine.setFormat(format)
        await engine.updatePerformanceMetrics { metrics in
            metrics.cpuUsage = 0.15
            metrics.memoryUsage = 0.10
            metrics.processingLatency = 0.005
        }
        
        return engine
    }
}