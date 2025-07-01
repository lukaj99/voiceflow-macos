import XCTest
import AVFoundation
@testable import VoiceFlowCore

class AudioEngineTests: XCTestCase {
    var audioEngine: AudioEngineManager!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngineManager()
    }
    
    override func tearDown() {
        Task {
            await audioEngine.stop()
        }
        audioEngine = nil
        super.tearDown()
    }
    
    func testAudioEngineInitialization() {
        XCTAssertNotNil(audioEngine)
        XCTAssertFalse(audioEngine.isRunning)
        XCTAssertFalse(audioEngine.isConfigured)
    }
    
    func testAudioSessionConfiguration() async throws {
        try await audioEngine.configureAudioSession()
        XCTAssertTrue(audioEngine.isConfigured)
    }
    
    func testAudioEngineStart() async throws {
        try await audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning)
        XCTAssertTrue(audioEngine.isConfigured)
    }
    
    func testAudioEngineStop() async throws {
        try await audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning)
        
        await audioEngine.stop()
        XCTAssertFalse(audioEngine.isRunning)
    }
    
    func testBufferProcessing() async throws {
        let expectation = XCTestExpectation(description: "Buffer processed")
        var bufferCount = 0
        
        audioEngine.onBufferProcessed = { buffer in
            XCTAssertEqual(buffer.frameLength, 256)
            XCTAssertEqual(buffer.format.sampleRate, 44100)
            XCTAssertEqual(buffer.format.channelCount, 1)
            bufferCount += 1
            if bufferCount >= 5 {
                expectation.fulfill()
            }
        }
        
        try await audioEngine.start()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testAudioLevelCalculation() async throws {
        let expectation = XCTestExpectation(description: "Audio level calculated")
        
        audioEngine.audioLevelPublisher
            .sink { level in
                XCTAssertGreaterThanOrEqual(level, 0.0)
                XCTAssertLessThanOrEqual(level, 1.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        try await audioEngine.start()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testErrorHandling() async {
        // Test starting without configuration
        do {
            audioEngine.isConfigured = false
            try await audioEngine.start()
            // Should auto-configure
            XCTAssertTrue(audioEngine.isConfigured)
        } catch {
            XCTFail("Should handle auto-configuration")
        }
    }
    
    func testMultipleStartStopCycles() async throws {
        for _ in 0..<3 {
            try await audioEngine.start()
            XCTAssertTrue(audioEngine.isRunning)
            
            await audioEngine.stop()
            XCTAssertFalse(audioEngine.isRunning)
        }
    }
    
    func testBufferSizeConfiguration() {
        XCTAssertEqual(audioEngine.bufferSize, 256)
        XCTAssertEqual(audioEngine.sampleRate, 44100)
    }
    
    // MARK: - Performance Tests
    
    func testBufferProcessingPerformance() throws {
        measure {
            let buffer = createTestBuffer()
            _ = audioEngine.calculateAudioLevel(from: buffer)
        }
    }
    
    // MARK: - Helpers
    
    private var cancellables = Set<AnyCancellable>()
    
    private func createTestBuffer() -> AVAudioPCMBuffer {
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
        
        // Fill with test data (sine wave)
        if let channelData = buffer.floatChannelData {
            for i in 0..<256 {
                channelData[0][i] = sin(Float(i) * 0.1) * 0.5
            }
        }
        
        return buffer
    }
}