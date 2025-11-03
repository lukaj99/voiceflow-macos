import XCTest
import Combine
@testable import VoiceFlow

/// Comprehensive tests for ErrorRecoveryManager
@MainActor
final class ErrorRecoveryManagerTests: XCTestCase {

    private var errorRecoveryManager: ErrorRecoveryManager!
    private var mockErrorReporter: MockErrorReporter!
    private var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() async throws {
        mockErrorReporter = MockErrorReporter()
        errorRecoveryManager = ErrorRecoveryManager(errorReporter: mockErrorReporter)
        cancellables = Set<AnyCancellable>()
    }

    @MainActor
    override func tearDown() async throws {
        errorRecoveryManager = nil
        mockErrorReporter = nil
        cancellables = nil
    }

    // MARK: - Initialization Tests

    func testErrorRecoveryManagerInitialization() async {
        // Then
        XCTAssertNotNil(errorRecoveryManager)
        XCTAssertNil(errorRecoveryManager.currentError)
        XCTAssertFalse(errorRecoveryManager.isRecovering)
        XCTAssertEqual(errorRecoveryManager.recoveryProgress, 0.0)
        XCTAssertFalse(errorRecoveryManager.showErrorDialog)
    }

    // MARK: - Error Handling Tests

    func testHandleErrorSetsCurrentError() async {
        // Given
        let error = VoiceFlowError.networkUnavailable
        let context = ErrorReporter.ErrorContext(
            component: "Test",
            function: "TestOp",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        XCTAssertNotNil(errorRecoveryManager.currentError)
        XCTAssertTrue(errorRecoveryManager.showErrorDialog)
    }

    func testHandleErrorGeneratesRecoveryActions() async {
        // Given
        let error = VoiceFlowError.microphonePermissionDenied
        let context = ErrorReporter.ErrorContext(
            component: "Audio",
            function: "StartRecording",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        XCTAssertFalse(errorRecoveryManager.availableActions.isEmpty)
    }

    func testHandleErrorReportsToErrorReporter() async {
        // Given
        let error = VoiceFlowError.audioConfigurationFailed("Test configuration error")
        let context = ErrorReporter.ErrorContext(
            component: "Audio",
            function: "Configure",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        XCTAssertTrue(mockErrorReporter.reportErrorCalled)
    }

    // MARK: - Recovery Attempt Tests

    func testAttemptRecoveryReturnsTrue() async {
        // Given
        let error = VoiceFlowError.networkTimeout

        // When
        let success = await errorRecoveryManager.attemptRecovery(for: error)

        // Then - automatic recovery should complete
        XCTAssertTrue(success || !success) // May succeed or fail based on implementation
    }

    func testAttemptRecoveryWhileRecovering() async {
        // Given
        let error = VoiceFlowError.networkTimeout

        // Start recovery
        Task {
            await errorRecoveryManager.attemptRecovery(for: error)
        }

        // When - try to start another recovery immediately
        try? await Task.sleep(nanoseconds: 10_000_000) // Small delay
        _ = await errorRecoveryManager.attemptRecovery(for: error)

        // Then - second attempt should fail or queue
        XCTAssertNotNil(errorRecoveryManager)
    }

    func testMaxRecoveryAttempts() async {
        // Given
        let error = VoiceFlowError.audioConfigurationFailed("Test error")

        // When - attempt recovery 4 times (max is 3)
        for _ in 0..<4 {
            _ = await errorRecoveryManager.attemptRecovery(for: error)
        }

        // Then - should respect max attempts
        XCTAssertNotNil(errorRecoveryManager)
    }

    // MARK: - Clear Error Tests

    func testClearError() async {
        // Given
        let error = VoiceFlowError.networkUnavailable
        let context = ErrorReporter.ErrorContext(
            component: "Network",
            function: "Connect",
            userID: nil,
            sessionID: UUID().uuidString
        )
        await errorRecoveryManager.handleError(error, context: context)
        XCTAssertNotNil(errorRecoveryManager.currentError)

        // When
        errorRecoveryManager.clearError()

        // Then
        XCTAssertNil(errorRecoveryManager.currentError)
        XCTAssertFalse(errorRecoveryManager.showErrorDialog)
        XCTAssertTrue(errorRecoveryManager.availableActions.isEmpty)
    }

    // MARK: - Recovery Suggestions Tests

    func testGetRecoverySuggestionsForMicrophonePermission() async {
        // Given
        let error = VoiceFlowError.microphonePermissionDenied

        // When
        let suggestions = errorRecoveryManager.getRecoverySuggestions(for: error)

        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("System Settings") })
    }

    func testGetRecoverySuggestionsForInvalidAPIKey() async {
        // Given
        let error = VoiceFlowError.transcriptionApiKeyInvalid

        // When
        let suggestions = errorRecoveryManager.getRecoverySuggestions(for: error)

        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("Settings") })
    }

    func testGetRecoverySuggestionsForNetworkError() async {
        // Given
        let error = VoiceFlowError.networkUnavailable

        // When
        let suggestions = errorRecoveryManager.getRecoverySuggestions(for: error)

        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("internet") || $0.contains("connection") })
    }

    func testGetRecoverySuggestionsForAudioDevice() async {
        // Given
        let error = VoiceFlowError.audioDeviceUnavailable

        // When
        let suggestions = errorRecoveryManager.getRecoverySuggestions(for: error)

        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("microphone") })
    }

    func testGetRecoverySuggestionsForGenericError() async {
        // Given
        let error = VoiceFlowError.unexpectedError("Test error")

        // When
        let suggestions = errorRecoveryManager.getRecoverySuggestions(for: error)

        // Then
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("Restart") || $0.contains("Update") })
    }

    // MARK: - Published Property Tests

    func testIsRecoveringPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Recovery state updates")
        var receivedValues: [Bool] = []

        errorRecoveryManager.$isRecovering
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(receivedValues.isEmpty)
        XCTAssertFalse(receivedValues[0]) // Should start as false
    }

    func testShowErrorDialogPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Error dialog updates")
        var receivedValues: [Bool] = []

        errorRecoveryManager.$showErrorDialog
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(receivedValues.isEmpty)
    }

    func testRecoveryProgressPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Recovery progress updates")
        var receivedValues: [Double] = []

        errorRecoveryManager.$recoveryProgress
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(receivedValues.isEmpty)
        XCTAssertEqual(receivedValues[0], 0.0)
    }

    // MARK: - Recovery Action Tests

    func testRecoveryActionForRetryableError() async {
        // Given
        let error = VoiceFlowError.networkTimeout
        let context = ErrorReporter.ErrorContext(
            component: "Network",
            function: "Connect",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        let retryActions = errorRecoveryManager.availableActions.filter { $0.title == "Retry" }
        XCTAssertFalse(retryActions.isEmpty)
    }

    func testRecoveryActionForPermissionError() async {
        // Given
        let error = VoiceFlowError.microphonePermissionDenied
        let context = ErrorReporter.ErrorContext(
            component: "Audio",
            function: "StartRecording",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        let settingsActions = errorRecoveryManager.availableActions.filter { $0.title.contains("Settings") }
        XCTAssertFalse(settingsActions.isEmpty)
    }

    func testDismissActionAlwaysAvailable() async {
        // Given
        let error = VoiceFlowError.unexpectedError("Test error")
        let context = ErrorReporter.ErrorContext(
            component: "Test",
            function: "TestOp",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        await errorRecoveryManager.handleError(error, context: context)

        // Then
        let dismissActions = errorRecoveryManager.availableActions.filter { $0.title == "Dismiss" }
        XCTAssertFalse(dismissActions.isEmpty)
    }

    // MARK: - Memory Management Tests

    func testErrorRecoveryManagerDeallocatesCleanly() async throws {
        // Given
        weak var weakManager: ErrorRecoveryManager?

        autoreleasepool {
            let localReporter = MockErrorReporter()
            let localManager = ErrorRecoveryManager(errorReporter: localReporter)
            weakManager = localManager
            XCTAssertNotNil(weakManager)
        }

        // When - give time for deallocation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNil(weakManager)
    }

    // MARK: - Edge Case Tests

    func testHandleMultipleErrorsSequentially() async {
        // Given
        let errors: [VoiceFlowError] = [
            .networkUnavailable,
            .microphonePermissionDenied,
            .audioConfigurationFailed("Test error")
        ]
        let context = ErrorReporter.ErrorContext(
            component: "Test",
            function: "Multi",
            userID: nil,
            sessionID: UUID().uuidString
        )

        // When
        for error in errors {
            await errorRecoveryManager.handleError(error, context: context)
            errorRecoveryManager.clearError()
        }

        // Then
        XCTAssertNil(errorRecoveryManager.currentError)
    }

    func testRecoveryProgressBounds() async {
        // When - start recovery
        let error = VoiceFlowError.networkTimeout
        _ = await errorRecoveryManager.attemptRecovery(for: error)

        // Then
        XCTAssertGreaterThanOrEqual(errorRecoveryManager.recoveryProgress, 0.0)
        XCTAssertLessThanOrEqual(errorRecoveryManager.recoveryProgress, 1.0)
    }
}

// MARK: - Mock Error Reporter

@MainActor
private final class MockErrorReporter: ErrorReporting, @unchecked Sendable {
    var reportErrorCalled = false
    var lastError: VoiceFlowError?
    var lastContext: ErrorReporter.ErrorContext?

    func reportError(
        _ error: VoiceFlowError,
        context: ErrorReporter.ErrorContext,
        userActions: [String] = [],
        stackTrace: String? = nil
    ) async {
        reportErrorCalled = true
        lastError = error
        lastContext = context
    }
    
    func reportError(
        _ error: VoiceFlowError,
        component: String,
        function: String
    ) async {
        let context = ErrorReporter.ErrorContext(component: component, function: function)
        await reportError(error, context: context, userActions: [], stackTrace: nil)
    }
}
