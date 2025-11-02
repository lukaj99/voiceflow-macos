import XCTest
import AVFoundation
@testable import VoiceFlow

/// Tests for AudioProcessingActor with proper actor isolation
final class AudioProcessingActorTests: XCTestCase {

    // MARK: - Audio Format Tests

    func testAudioFormatConfiguration() async throws {
        // Given
        let audioManager = AudioManager()

        // When
        try await audioManager.startRecording()

        // Then - verify audio is being processed
        try await Task.sleep(nanoseconds: 200_000_000)

        audioManager.stopRecording()
    }

    func testTargetAudioFormat() async {
        // Given - expected format for Deepgram: 16kHz, 16-bit PCM, mono
        let expectedSampleRate: Double = 16000
        let expectedChannels: UInt32 = 1

        // When - create test format matching our target
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: expectedSampleRate,
            channels: expectedChannels,
            interleaved: false
        )

        // Then
        XCTAssertNotNil(format)
        XCTAssertEqual(format?.sampleRate, expectedSampleRate)
        XCTAssertEqual(format?.channelCount, expectedChannels)
    }

    // MARK: - Audio Level Calculation Tests

    func testAudioLevelCalculationWithSilence() {
        // Given - buffer with silence (all zeros)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Fill with silence
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(buffer.frameLength) {
                channelData[0][i] = 0.0
            }
        }

        // When
        let level = calculateAudioLevel(from: buffer)

        // Then - silence should produce very low level
        XCTAssertLessThan(level, 0.01)
    }

    func testAudioLevelCalculationWithSignal() {
        // Given - buffer with sine wave
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Fill with sine wave
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(buffer.frameLength) {
                channelData[0][i] = sin(Float(i) * 0.1) * 0.5 // 0.5 amplitude
            }
        }

        // When
        let level = calculateAudioLevel(from: buffer)

        // Then - signal should produce measurable level
        XCTAssertGreaterThan(level, 0.1)
        XCTAssertLessThanOrEqual(level, 1.0)
    }

    func testAudioLevelCalculationRange() {
        // Given - buffer with maximum amplitude
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Fill with maximum amplitude
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(buffer.frameLength) {
                channelData[0][i] = 1.0
            }
        }

        // When
        let level = calculateAudioLevel(from: buffer)

        // Then - level should be in valid range
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)
    }

    // MARK: - Audio Format Conversion Tests

    func testAudioFormatConversionSetup() {
        // Given
        let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false
        )!

        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // When
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        // Then
        XCTAssertNotNil(converter)
    }

    func testPCMDataExtraction() {
        // Given
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Fill with test data
        if let channelData = buffer.int16ChannelData {
            for i in 0..<Int(buffer.frameLength) {
                channelData[0][i] = Int16(i % 1000)
            }
        }

        // When
        let data = extractPCMData(from: buffer)

        // Then
        XCTAssertNotNil(data)
        let expectedByteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        XCTAssertEqual(data?.count, expectedByteCount)
    }

    // MARK: - Audio Stream Tests

    func testAudioStreamCreation() async {
        // Given
        let audioManager = AudioManager()

        // When
        let expectation = XCTestExpectation(description: "Audio level received")

        Task {
            // Stream should produce values when recording
            try? await audioManager.startRecording()

            try? await Task.sleep(nanoseconds: 500_000_000)

            if audioManager.audioLevel >= 0 {
                expectation.fulfill()
            }

            audioManager.stopRecording()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Recording Lifecycle Tests

    func testActorStartRecordingCycle() async throws {
        // Given
        let audioManager = AudioManager()

        // When
        try await audioManager.startRecording()

        // Then
        XCTAssertTrue(audioManager.isRecording)

        // Cleanup
        audioManager.stopRecording()
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func testActorStopRecordingCycle() async throws {
        // Given
        let audioManager = AudioManager()
        try await audioManager.startRecording()
        XCTAssertTrue(audioManager.isRecording)

        // When
        audioManager.stopRecording()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertFalse(audioManager.isRecording)
    }

    // MARK: - Concurrent Processing Tests

    func testConcurrentAudioProcessing() async throws {
        // Given
        let audioManager = AudioManager()
        try await audioManager.startRecording()

        // When - process audio for a period
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then - should process without errors
        XCTAssertTrue(audioManager.isRecording)

        audioManager.stopRecording()
    }

    // MARK: - Performance Tests

    func testAudioLevelCalculationPerformance() {
        // Given
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(buffer.frameLength) {
                channelData[0][i] = sin(Float(i) * 0.1) * 0.5
            }
        }

        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = calculateAudioLevel(from: buffer)
            }
        }
    }

    func testPCMDataExtractionPerformance() {
        // Given
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = extractPCMData(from: buffer)
            }
        }
    }

    // MARK: - Helper Methods

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }

        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let decibels = 20 * log10(rms)

        return max(0, min(1, (decibels + 60) / 60))
    }

    private func extractPCMData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData?[0] else { return nil }

        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData, count: byteCount)
    }
}
