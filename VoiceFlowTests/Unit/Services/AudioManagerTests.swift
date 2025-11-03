import XCTest
import AVFoundation
@testable import VoiceFlow

/// Comprehensive tests for AudioManager with Swift 6 actor isolation
@MainActor
final class AudioManagerTests: XCTestCase {

    private var audioManager: AudioManager!
    private var mockDelegate: MockAudioManagerDelegate!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        audioManager = AudioManager()
        mockDelegate = MockAudioManagerDelegate()
        audioManager.delegate = mockDelegate
    }

    @MainActor
    override func tearDown() async throws {
        if audioManager.isRecording {
            audioManager.stopRecording()
        }
        audioManager = nil
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testAudioManagerInitialization() async {
        // Then
        XCTAssertFalse(audioManager.isRecording)
        XCTAssertEqual(audioManager.audioLevel, 0.0)
    }

    // MARK: - Recording State Tests

    func testStartRecording() async throws {
        // Given
        XCTAssertFalse(audioManager.isRecording)

        // When
        try await audioManager.startRecording()

        // Then
        XCTAssertTrue(audioManager.isRecording)
    }

    func testStopRecording() async throws {
        // Given
        try await audioManager.startRecording()
        XCTAssertTrue(audioManager.isRecording)

        // When
        audioManager.stopRecording()

        // Small delay for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then
        XCTAssertFalse(audioManager.isRecording)
        XCTAssertEqual(audioManager.audioLevel, 0.0)
    }

    func testStartRecordingWhenAlreadyRecording() async throws {
        // Given
        try await audioManager.startRecording()
        XCTAssertTrue(audioManager.isRecording)

        // When - try to start again
        try await audioManager.startRecording()

        // Then - should still be recording, no error
        XCTAssertTrue(audioManager.isRecording)
    }

    func testStopRecordingWhenNotRecording() async {
        // Given
        XCTAssertFalse(audioManager.isRecording)

        // When
        audioManager.stopRecording()

        // Then - should handle gracefully
        XCTAssertFalse(audioManager.isRecording)
    }

    // MARK: - Pause/Resume Tests

    func testPauseRecording() async throws {
        // Given
        try await audioManager.startRecording()
        XCTAssertTrue(audioManager.isRecording)

        // When
        audioManager.pauseRecording()

        // Small delay
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then
        XCTAssertTrue(audioManager.isRecording) // Still technically recording state
    }

    func testResumeRecording() async throws {
        // Given
        try await audioManager.startRecording()
        audioManager.pauseRecording()

        // When
        audioManager.resumeRecording()

        // Small delay
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then
        XCTAssertTrue(audioManager.isRecording)
    }

    func testPauseWhenNotRecording() async {
        // Given
        XCTAssertFalse(audioManager.isRecording)

        // When
        audioManager.pauseRecording()

        // Then - should handle gracefully
        XCTAssertFalse(audioManager.isRecording)
    }

    // MARK: - Audio Level Tests

    func testAudioLevelInitialState() async {
        // Then
        XCTAssertEqual(audioManager.audioLevel, 0.0)
    }

    func testAudioLevelRangeValidation() async throws {
        // Given
        try await audioManager.startRecording()

        // Wait for some audio processing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Then
        XCTAssertGreaterThanOrEqual(audioManager.audioLevel, 0.0)
        XCTAssertLessThanOrEqual(audioManager.audioLevel, 1.0)
    }

    func testAudioLevelResetsOnStop() async throws {
        // Given
        try await audioManager.startRecording()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // When
        audioManager.stopRecording()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(audioManager.audioLevel, 0.0)
    }

    // MARK: - Delegate Tests

    func testDelegateReceivesAudioData() async throws {
        // Given
        try await audioManager.startRecording()

        // When - wait for audio data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        // Then
        XCTAssertTrue(mockDelegate.didReceiveAudioDataCalled)
        XCTAssertGreaterThan(mockDelegate.audioDataReceived.count, 0)
    }

    func testDelegateNotCalledWhenNotRecording() async throws {
        // Given
        XCTAssertFalse(audioManager.isRecording)

        // When - wait
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Then
        XCTAssertFalse(mockDelegate.didReceiveAudioDataCalled)
    }

    func testDelegateStopsReceivingAfterStop() async throws {
        // Given
        try await audioManager.startRecording()
        try await Task.sleep(nanoseconds: 500_000_000)

        // When
        audioManager.stopRecording()
        mockDelegate.reset()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertFalse(mockDelegate.didReceiveAudioDataCalled)
    }

    // MARK: - Multiple Cycle Tests

    func testMultipleStartStopCycles() async throws {
        // When/Then - multiple cycles
        for _ in 0..<3 {
            try await audioManager.startRecording()
            XCTAssertTrue(audioManager.isRecording)

            try await Task.sleep(nanoseconds: 200_000_000)

            audioManager.stopRecording()
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertFalse(audioManager.isRecording)
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentStateAccess() async throws {
        // Given
        try await audioManager.startRecording()

        // When - concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask { @MainActor in
                    return self.audioManager.isRecording
                }
            }

            // Then - all should succeed
            for await result in group {
                XCTAssertTrue(result)
            }
        }
    }

    // MARK: - Memory Management Tests

    func testAudioManagerDeallocatesCleanly() async throws {
        // Given
        weak var weakAudioManager: AudioManager?

        autoreleasepool {
            let localManager = AudioManager()
            weakAudioManager = localManager
            XCTAssertNotNil(weakAudioManager)
        }

        // When - give time for deallocation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNil(weakAudioManager)
    }

    // MARK: - Error Handling Tests

    func testStartRecordingWithoutMicrophonePermission() async {
        // Note: In real testing environment, microphone permission is typically granted
        // This test verifies the code path exists
        do {
            try await audioManager.startRecording()
            // If we reach here, permission was granted (typical case)
            XCTAssertTrue(audioManager.isRecording)
        } catch AudioError.microphonePermissionDenied {
            // This is the expected error if permission denied
            XCTAssertFalse(audioManager.isRecording)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testAudioManagerCreationPerformance() {
        measure {
            autoreleasepool {
                _ = AudioManager()
            }
        }
    }

    func testStartStopPerformance() async throws {
        // Measure start/stop cycle performance
        measure {
            Task { @MainActor in
                do {
                    try await self.audioManager.startRecording()
                    try await Task.sleep(nanoseconds: 50_000_000)
                    self.audioManager.stopRecording()
                    try await Task.sleep(nanoseconds: 50_000_000)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Mock Delegate

@MainActor
private class MockAudioManagerDelegate: AudioManagerDelegate {
    var didReceiveAudioDataCalled = false
    var audioDataReceived: [Data] = []

    func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data) {
        didReceiveAudioDataCalled = true
        audioDataReceived.append(data)
    }

    func reset() {
        didReceiveAudioDataCalled = false
        audioDataReceived.removeAll()
    }
}
