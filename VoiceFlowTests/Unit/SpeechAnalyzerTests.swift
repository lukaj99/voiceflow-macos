import XCTest
import Speech
import AVFoundation
import Combine
@testable import VoiceFlowCore

class SpeechAnalyzerEngineTests: XCTestCase {
    var engine: SpeechAnalyzerEngine!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        engine = SpeechAnalyzerEngine()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        Task {
            await engine.stopTranscription()
        }
        cancellables = nil
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testAnalyzerConfiguration() async {
        let config = await engine.configuration
        
        XCTAssertEqual(config.model, .enhanced)
        XCTAssertTrue(config.enableSpeculativeDecoding)
        XCTAssertTrue(config.enablePunctuation)
        XCTAssertTrue(config.enableCapitalization)
        XCTAssertTrue(config.enablePartialResults)
        XCTAssertEqual(config.confidenceThreshold, 0.85)
        XCTAssertEqual(config.maxAlternatives, 3)
    }
    
    func testLanguageConfiguration() async {
        await engine.setLanguage("en-US")
        let config = await engine.configuration
        XCTAssertEqual(config.language, .english)
        
        await engine.setLanguage("es-ES")
        let updatedConfig = await engine.configuration
        XCTAssertEqual(updatedConfig.language, .spanish)
    }
    
    // MARK: - Latency Tests
    
    func testTranscriptionLatencyP50() async throws {
        let measurements = await measureLatency(iterations: 20)
        let p50 = percentile(measurements, 0.5)
        XCTAssertLessThan(p50, 0.030, "P50 latency should be under 30ms")
    }
    
    func testTranscriptionLatencyP95() async throws {
        let measurements = await measureLatency(iterations: 100)
        let p95 = percentile(measurements, 0.95)
        XCTAssertLessThan(p95, 0.050, "P95 latency should be under 50ms")
    }
    
    func testTranscriptionLatencyP99() async throws {
        let measurements = await measureLatency(iterations: 100)
        let p99 = percentile(measurements, 0.99)
        XCTAssertLessThan(p99, 0.100, "P99 latency should be under 100ms")
    }
    
    // MARK: - Result Handling Tests
    
    func testPartialResultHandling() async throws {
        let expectation = XCTestExpectation(description: "Partial results received")
        var partialCount = 0
        var finalCount = 0
        
        await engine.transcriptionPublisher
            .sink { update in
                switch update.type {
                case .partial:
                    partialCount += 1
                    XCTAssertFalse(update.text.isEmpty)
                    XCTAssertGreaterThan(update.confidence, 0)
                case .final:
                    finalCount += 1
                    XCTAssertFalse(update.text.isEmpty)
                    XCTAssertNotNil(update.wordTimings)
                case .correction:
                    break
                }
                
                if partialCount >= 3 && finalCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await engine.startTranscription()
        
        // Simulate audio input
        await simulateAudioInput(duration: 3.0)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(partialCount, 0)
        XCTAssertGreaterThan(finalCount, 0)
    }
    
    func testAlternativesGeneration() async throws {
        let expectation = XCTestExpectation(description: "Alternatives received")
        
        await engine.transcriptionPublisher
            .sink { update in
                if let alternatives = update.alternatives {
                    XCTAssertGreaterThan(alternatives.count, 0)
                    XCTAssertLessThanOrEqual(alternatives.count, 3)
                    
                    // Verify alternatives are sorted by confidence
                    for i in 1..<alternatives.count {
                        XCTAssertLessThanOrEqual(
                            alternatives[i].confidence,
                            alternatives[i-1].confidence
                        )
                    }
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await engine.startTranscription()
        await simulateAudioInput(duration: 2.0)
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Context Tests
    
    func testContextAwareTranscription() async throws {
        // Set coding context
        await engine.setContext(.coding(language: .swift))
        
        let expectation = XCTestExpectation(description: "Context-aware transcription")
        
        await engine.transcriptionPublisher
            .sink { update in
                if update.type == .final {
                    // Should recognize Swift keywords better
                    let swiftKeywords = ["func", "var", "let", "class", "struct"]
                    let containsKeyword = swiftKeywords.contains { update.text.contains($0) }
                    if containsKeyword {
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        try await engine.startTranscription()
        await simulateAudioInput(duration: 2.0)
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Custom Vocabulary Tests
    
    func testCustomVocabulary() async throws {
        let customWords = ["SwiftUI", "ObservableObject", "@Published", "VoiceFlow"]
        await engine.addCustomVocabulary(customWords)
        
        let expectation = XCTestExpectation(description: "Custom vocabulary recognized")
        
        await engine.transcriptionPublisher
            .sink { update in
                if update.type == .final {
                    let containsCustomWord = customWords.contains { word in
                        update.text.contains(word)
                    }
                    if containsCustomWord {
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        try await engine.startTranscription()
        await simulateAudioInput(duration: 2.0)
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - State Management Tests
    
    func testStartStopCycle() async throws {
        for _ in 0..<3 {
            try await engine.startTranscription()
            let isRunning1 = await engine.isTranscribing
            XCTAssertTrue(isRunning1)
            
            await engine.stopTranscription()
            let isRunning2 = await engine.isTranscribing
            XCTAssertFalse(isRunning2)
        }
    }
    
    func testPauseResume() async throws {
        try await engine.startTranscription()
        
        await engine.pauseTranscription()
        let isPaused = await engine.isPaused
        XCTAssertTrue(isPaused)
        
        await engine.resumeTranscription()
        let isResumed = await engine.isPaused
        XCTAssertFalse(isResumed)
    }
    
    // MARK: - Error Handling Tests
    
    func testModelLoadFailure() async {
        // Force model failure
        await engine.setModel(.unavailable)
        
        do {
            try await engine.startTranscription()
            XCTFail("Should throw model load failure")
        } catch VoiceFlowError.modelLoadFailure {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testLanguageNotSupported() async {
        await engine.setLanguage("xx-XX") // Invalid language
        
        do {
            try await engine.startTranscription()
            XCTFail("Should throw language not supported")
        } catch VoiceFlowError.languageNotSupported {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testMemoryUsage() async throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            let expectation = XCTestExpectation(description: "Transcription complete")
            
            Task {
                try await engine.startTranscription()
                await simulateAudioInput(duration: 10.0)
                await engine.stopTranscription()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testCPUUsage() async throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTCPUMetric()], options: options) {
            let expectation = XCTestExpectation(description: "Transcription complete")
            
            Task {
                try await engine.startTranscription()
                await simulateAudioInput(duration: 5.0)
                await engine.stopTranscription()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func measureLatency(iterations: Int) async -> [TimeInterval] {
        var measurements: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let buffer = createTestAudioBuffer()
            let start = CFAbsoluteTimeGetCurrent()
            
            await engine.processAudioBuffer(buffer, at: AVAudioTime(hostTime: mach_absolute_time()))
            
            let latency = CFAbsoluteTimeGetCurrent() - start
            measurements.append(latency)
        }
        
        return measurements
    }
    
    private func percentile(_ values: [TimeInterval], _ p: Double) -> TimeInterval {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[index]
    }
    
    private func createTestAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
        
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 256
        )!
        
        buffer.frameLength = 256
        
        // Fill with test audio data
        if let channelData = buffer.floatChannelData {
            for i in 0..<256 {
                // Simulate speech-like waveform
                let frequency = 200.0 + sin(Float(i) * 0.01) * 50
                channelData[0][i] = sin(Float(i) * Float.pi * 2 * frequency / 44100) * 0.3
            }
        }
        
        return buffer
    }
    
    private func simulateAudioInput(duration: TimeInterval) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < duration {
            let buffer = createTestAudioBuffer()
            await engine.processAudioBuffer(buffer, at: AVAudioTime(hostTime: mach_absolute_time()))
            
            // Simulate real-time audio rate (256 samples at 44.1kHz = ~5.8ms)
            try? await Task.sleep(nanoseconds: 5_800_000)
        }
    }
}

// MARK: - Mock Extensions for Testing

extension SpeechAnalyzerEngine {
    enum TestModel {
        case enhanced
        case basic
        case unavailable
    }
    
    func setModel(_ model: TestModel) async {
        // Mock method for testing
    }
}