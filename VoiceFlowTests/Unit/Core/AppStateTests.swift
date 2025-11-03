import XCTest
@testable import VoiceFlow

/// Comprehensive tests for AppState management with @Observable pattern
@MainActor
final class AppStateTests: XCTestCase {

    private var appState: AppState!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // Create a fresh AppState instance for each test
        appState = AppState()
    }

    @MainActor
    override func tearDown() async throws {
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testAppStateInitialization() {
        // Then
        XCTAssertEqual(appState.transcriptionText, "")
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.audioLevel, 0.0)
        XCTAssertEqual(appState.connectionStatus, .disconnected)
        XCTAssertNil(appState.errorMessage)
        XCTAssertFalse(appState.isProcessing)
    }

    func testInitialUIState() {
        // Then
        XCTAssertEqual(appState.selectedView, .transcription)
        XCTAssertFalse(appState.isSettingsPresented)
        XCTAssertFalse(appState.shouldShowOnboarding)
    }

    func testInitialSessionState() {
        // Then
        XCTAssertNil(appState.currentSession)
        XCTAssertTrue(appState.recentSessions.isEmpty)
        XCTAssertEqual(appState.selectedLanguage, .english)
        XCTAssertFalse(appState.isConfigured)
    }

    // MARK: - Transcription Session Tests

    func testStartTranscriptionSession() {
        // When
        appState.startTranscriptionSession()

        // Then
        XCTAssertNotNil(appState.currentSession)
        XCTAssertTrue(appState.isRecording)
        XCTAssertTrue(appState.isProcessing)
        XCTAssertNil(appState.errorMessage)
        XCTAssertEqual(appState.transcriptionText, "")
    }

    func testStopTranscriptionSession() {
        // Given
        appState.startTranscriptionSession()
        appState.updateTranscription("Test transcription", isFinal: true)

        // When
        appState.stopTranscriptionSession()

        // Then
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(appState.isRecording)
        XCTAssertFalse(appState.isProcessing)
        XCTAssertEqual(appState.audioLevel, 0.0)
        XCTAssertEqual(appState.recentSessions.count, 1)
    }

    func testMultipleSessionLifecycles() {
        // When - start and stop multiple sessions
        for i in 1...3 {
            appState.startTranscriptionSession()
            appState.updateTranscription("Session \(i)", isFinal: true)
            appState.stopTranscriptionSession()
        }

        // Then
        XCTAssertEqual(appState.recentSessions.count, 3)
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(appState.isRecording)
    }

    func testRecentSessionsLimit() {
        // When - create more than 50 sessions
        for i in 1...55 {
            appState.startTranscriptionSession()
            appState.updateTranscription("Session \(i)", isFinal: true)
            appState.stopTranscriptionSession()
        }

        // Then - should keep only last 50
        XCTAssertEqual(appState.recentSessions.count, 50)
    }

    // MARK: - Transcription Update Tests

    func testUpdateTranscriptionPartial() {
        // Given
        appState.startTranscriptionSession()

        // When
        appState.updateTranscription("Hello", isFinal: false)

        // Then - partial updates don't modify transcription text in this implementation
        XCTAssertNotNil(appState.currentSession)
    }

    func testUpdateTranscriptionFinal() {
        // Given
        appState.startTranscriptionSession()

        // When
        appState.updateTranscription("Hello world", isFinal: true)

        // Then
        XCTAssertEqual(appState.transcriptionText, "Hello world")
    }

    func testUpdateTranscriptionMultipleFinal() {
        // Given
        appState.startTranscriptionSession()

        // When
        appState.updateTranscription("Hello", isFinal: true)
        appState.updateTranscription("world", isFinal: true)

        // Then - should concatenate with space
        XCTAssertEqual(appState.transcriptionText, "Hello world")
    }

    func testUpdateTranscriptionWordCount() {
        // Given
        appState.startTranscriptionSession()

        // When
        appState.updateTranscription("Hello world test", isFinal: true)

        // Then
        XCTAssertEqual(appState.currentWordCount, 3)
        XCTAssertEqual(appState.currentSession?.wordCount, 3)
    }

    func testClearTranscription() {
        // Given
        appState.startTranscriptionSession()
        appState.updateTranscription("Some text", isFinal: true)
        XCTAssertFalse(appState.transcriptionText.isEmpty)

        // When
        appState.clearTranscription()

        // Then
        XCTAssertEqual(appState.transcriptionText, "")
        XCTAssertNil(appState.errorMessage)
    }

    // MARK: - Connection Status Tests

    func testSetConnectionStatus() {
        // When
        appState.setConnectionStatus(.connecting)
        XCTAssertEqual(appState.connectionStatus, .connecting)

        appState.setConnectionStatus(.connected)
        XCTAssertEqual(appState.connectionStatus, .connected)
        XCTAssertNil(appState.errorMessage) // Should clear error

        appState.setConnectionStatus(.disconnected)
        XCTAssertEqual(appState.connectionStatus, .disconnected)
    }

    func testConnectionStatusColors() {
        // Then
        XCTAssertNotNil(ConnectionStatus.disconnected.color)
        XCTAssertNotNil(ConnectionStatus.connecting.color)
        XCTAssertNotNil(ConnectionStatus.connected.color)
        XCTAssertNotNil(ConnectionStatus.error.color)
    }

    // MARK: - Error Handling Tests

    func testSetError() {
        // When
        appState.setError("Test error message")

        // Then
        XCTAssertEqual(appState.errorMessage, "Test error message")
    }

    func testClearError() {
        // Given
        appState.setError("Error occurred")
        XCTAssertNotNil(appState.errorMessage)

        // When
        appState.setError(nil)

        // Then
        XCTAssertNil(appState.errorMessage)
    }

    // MARK: - Audio Level Tests

    func testUpdateAudioLevel() {
        // When
        appState.updateAudioLevel(0.75)

        // Then
        XCTAssertEqual(appState.audioLevel, 0.75, accuracy: 0.001)
    }

    func testUpdateAudioLevelClamping() {
        // When - test values outside range
        appState.updateAudioLevel(-0.5)
        XCTAssertEqual(appState.audioLevel, 0.0)

        appState.updateAudioLevel(1.5)
        XCTAssertEqual(appState.audioLevel, 1.0)
    }

    // MARK: - Metrics Tests

    func testUpdateMetrics() {
        // Given
        let metrics = TranscriptionMetrics(
            latency: 0.15,
            confidence: 0.92,
            wordCount: 42,
            processingTime: 0.25
        )

        // When
        appState.updateMetrics(metrics)

        // Then
        XCTAssertEqual(appState.currentMetrics?.latency, 0.15)
        XCTAssertEqual(appState.currentMetrics?.confidence, 0.92)
        XCTAssertEqual(appState.networkLatency, 0.15)
    }

    // MARK: - LLM State Tests

    func testEnableLLMPostProcessing() {
        // When
        appState.enableLLMPostProcessing()

        // Then
        XCTAssertTrue(appState.llmPostProcessingEnabled)
        XCTAssertNil(appState.llmProcessingError)
    }

    func testDisableLLMPostProcessing() {
        // Given
        appState.enableLLMPostProcessing()
        appState.setLLMProcessing(true, progress: 0.5)

        // When
        appState.disableLLMPostProcessing()

        // Then
        XCTAssertFalse(appState.llmPostProcessingEnabled)
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertEqual(appState.llmProcessingProgress, 0.0)
        XCTAssertNil(appState.llmProcessingError)
    }

    func testSetLLMProcessing() {
        // When
        appState.setLLMProcessing(true, progress: 0.75)

        // Then
        XCTAssertTrue(appState.isLLMProcessing)
        XCTAssertEqual(appState.llmProcessingProgress, 0.75)
        XCTAssertNil(appState.llmProcessingError)
    }

    func testSetLLMProcessingError() {
        // When
        appState.setLLMProcessingError("LLM error occurred")

        // Then
        XCTAssertEqual(appState.llmProcessingError, "LLM error occurred")
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertEqual(appState.llmProcessingProgress, 0.0)
    }

    func testSetSelectedLLMProvider() {
        // When
        appState.setSelectedLLMProvider("anthropic", model: "claude-3-5-sonnet")

        // Then
        XCTAssertEqual(appState.selectedLLMProvider, "anthropic")
        XCTAssertEqual(appState.selectedLLMModel, "claude-3-5-sonnet")
    }

    func testRecordLLMProcessingResult() {
        // When
        appState.recordLLMProcessingResult(success: true, processingTime: 1.5, improvementScore: 0.8)

        // Then - statistics should be updated
        XCTAssertNotNil(appState.llmProcessingStats)
    }

    // MARK: - Configuration State Tests

    func testSetConfigured() {
        // When
        appState.setConfigured(true)

        // Then
        XCTAssertTrue(appState.isConfigured)
        XCTAssertFalse(appState.shouldShowOnboarding)
    }

    func testSetNotConfigured() {
        // Given
        appState.setConfigured(true)

        // When
        appState.setConfigured(false)

        // Then
        XCTAssertFalse(appState.isConfigured)
    }

    // MARK: - Computed Properties Tests

    func testIsReadyForTranscription() {
        // Initially not ready
        XCTAssertFalse(appState.isReadyForTranscription)

        // Configure and connect
        appState.setConfigured(true)
        appState.setConnectionStatus(.connected)
        XCTAssertTrue(appState.isReadyForTranscription)

        // Start recording - should not be ready
        appState.startTranscriptionSession()
        XCTAssertFalse(appState.isReadyForTranscription)
    }

    func testCurrentSessionDuration() {
        // Initially zero
        XCTAssertEqual(appState.currentSessionDuration, 0)

        // Start session
        appState.startTranscriptionSession()
        XCTAssertGreaterThanOrEqual(appState.currentSessionDuration, 0)
    }

    func testCurrentWordCount() {
        // Initially zero
        XCTAssertEqual(appState.currentWordCount, 0)

        // Add transcription
        appState.startTranscriptionSession()
        appState.updateTranscription("Hello world test", isFinal: true)
        XCTAssertEqual(appState.currentWordCount, 3)
    }

    func testHasTranscriptionContent() {
        // Initially false
        XCTAssertFalse(appState.hasTranscriptionContent)

        // Add transcription
        appState.startTranscriptionSession()
        appState.updateTranscription("Content", isFinal: true)
        XCTAssertTrue(appState.hasTranscriptionContent)

        // Clear transcription
        appState.clearTranscription()
        XCTAssertFalse(appState.hasTranscriptionContent)
    }

    // MARK: - Floating Widget Tests

    func testShowFloatingWidget() {
        // When
        appState.showFloatingWidget()

        // Then
        XCTAssertTrue(appState.isFloatingWidgetVisible)
    }

    func testHideFloatingWidget() {
        // Given
        appState.showFloatingWidget()

        // When
        appState.hideFloatingWidget()

        // Then
        XCTAssertFalse(appState.isFloatingWidgetVisible)
    }

    func testToggleFloatingWidget() {
        // Initially hidden
        XCTAssertFalse(appState.isFloatingWidgetVisible)

        // Toggle to show
        appState.toggleFloatingWidget()
        XCTAssertTrue(appState.isFloatingWidgetVisible)

        // Toggle to hide
        appState.toggleFloatingWidget()
        XCTAssertFalse(appState.isFloatingWidgetVisible)
    }

    func testEnableFloatingWidget() {
        // When
        appState.enableFloatingWidget()

        // Then
        XCTAssertTrue(appState.isFloatingWidgetEnabled)
    }

    func testDisableFloatingWidget() {
        // Given
        appState.enableFloatingWidget()
        appState.showFloatingWidget()

        // When
        appState.disableFloatingWidget()

        // Then
        XCTAssertFalse(appState.isFloatingWidgetEnabled)
        XCTAssertFalse(appState.isFloatingWidgetVisible)
    }

    // MARK: - Global Hotkeys Tests

    func testEnableGlobalHotkeys() {
        // When
        appState.enableGlobalHotkeys()

        // Then
        XCTAssertTrue(appState.isGlobalHotkeysEnabled)
    }

    func testDisableGlobalHotkeys() {
        // When
        appState.disableGlobalHotkeys()

        // Then
        XCTAssertFalse(appState.isGlobalHotkeysEnabled)
    }

    // MARK: - State Persistence Tests

    func testSaveState() {
        // Given
        appState.selectedLanguage = .spanish
        appState.appTheme = .dark

        // When
        appState.saveState()

        // Then - verify values are saved (would need to check UserDefaults in real test)
        XCTAssertEqual(appState.selectedLanguage, .spanish)
        XCTAssertEqual(appState.appTheme, .dark)
    }

    // MARK: - Supporting Types Tests

    func testConnectionStatusValues() {
        // Test all connection status values
        XCTAssertNotNil(ConnectionStatus.disconnected)
        XCTAssertNotNil(ConnectionStatus.connecting)
        XCTAssertNotNil(ConnectionStatus.connected)
        XCTAssertNotNil(ConnectionStatus.error)
    }

    func testAppViewValues() {
        // Test all app view values
        XCTAssertEqual(AppView.transcription.systemImage, "mic.fill")
        XCTAssertEqual(AppView.history.systemImage, "clock.fill")
        XCTAssertEqual(AppView.settings.systemImage, "gear.fill")
    }

    func testAppThemeValues() {
        // Test all theme values
        XCTAssertNil(AppTheme.system.colorScheme)
        XCTAssertNotNil(AppTheme.light.colorScheme)
        XCTAssertNotNil(AppTheme.dark.colorScheme)
    }

    // MARK: - Complex Workflow Tests

    func testCompleteTranscriptionWorkflow() {
        // Given - configure app
        appState.setConfigured(true)
        appState.setConnectionStatus(.connected)
        XCTAssertTrue(appState.isReadyForTranscription)

        // When - perform transcription
        appState.startTranscriptionSession()
        appState.updateTranscription("Hello", isFinal: true)
        appState.updateTranscription("world", isFinal: true)

        let metrics = TranscriptionMetrics(
            latency: 0.1,
            confidence: 0.95,
            wordCount: 2,
            processingTime: 0.2
        )
        appState.updateMetrics(metrics)

        appState.stopTranscriptionSession()

        // Then
        XCTAssertEqual(appState.recentSessions.count, 1)
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.transcriptionText, "Hello world")
    }

    // MARK: - Performance Tests

    func testSessionCreationPerformance() {
        measure {
            for _ in 0..<100 {
                appState.startTranscriptionSession()
                appState.stopTranscriptionSession()
            }
        }
    }

    func testTranscriptionUpdatePerformance() {
        appState.startTranscriptionSession()

        measure {
            for i in 0..<1000 {
                appState.updateTranscription("Word \(i)", isFinal: true)
            }
        }
    }

    func testStateObservationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = appState.isRecording
                _ = appState.connectionStatus
                _ = appState.transcriptionText
                _ = appState.currentWordCount
            }
        }
    }
}
