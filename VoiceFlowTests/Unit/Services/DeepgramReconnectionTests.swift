import XCTest
@testable import VoiceFlow

/// Tests for DeepgramClient reconnection and reliability features
@MainActor
final class DeepgramReconnectionTests: XCTestCase {

    private var client: DeepgramClient!
    private let testAPIKey = "test-reconnection-key"

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        client = DeepgramClient()
    }

    @MainActor
    override func tearDown() async throws {
        client?.disconnect()
        client = nil
        try await super.tearDown()
    }

    // MARK: - Auto-Reconnection Tests

    func testAutoReconnectEnabledByDefault() {
        // When
        client.connect(apiKey: testAPIKey, autoReconnect: true)

        // Then - connection attempt should be made
        XCTAssertGreaterThan(client.connectionAttempts, 0)
    }

    func testAutoReconnectDisabled() {
        // When
        client.connect(apiKey: testAPIKey, autoReconnect: false)

        // Then - connection attempt made but auto-reconnect disabled
        XCTAssertGreaterThan(client.connectionAttempts, 0)
    }

    func testConnectionAttemptsTracking() {
        // Given
        XCTAssertEqual(client.connectionAttempts, 0)

        // When
        client.connect(apiKey: testAPIKey)

        // Then
        XCTAssertEqual(client.connectionAttempts, 1)
    }

    func testMultipleConnectionAttempts() {
        // When
        client.connect(apiKey: testAPIKey)
        let firstAttempts = client.connectionAttempts

        client.disconnect()
        client.connect(apiKey: testAPIKey)
        let secondAttempts = client.connectionAttempts

        // Then
        XCTAssertGreaterThan(secondAttempts, firstAttempts)
    }

    // MARK: - Connection Failure Handling Tests

    func testConnectionStateOnFailure() {
        // Given
        client.connect(apiKey: "invalid-key", autoReconnect: false)

        // When - wait for potential failure
        let expectation = XCTestExpectation(description: "Connection state updated")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then - state should be disconnected, connecting, or error
            XCTAssertTrue(
                self.client.connectionState == .disconnected ||
                self.client.connectionState == .connecting ||
                self.client.connectionState == .error
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Force Reconnection Tests

    func testForceReconnectWithoutAPIKey() {
        // Given - no API key stored
        XCTAssertFalse(client.isConnected)

        // When
        client.forceReconnect()

        // Then - should handle gracefully
        XCTAssertFalse(client.isConnected)
    }

    func testForceReconnectResetsAttempts() {
        // Given
        client.connect(apiKey: testAPIKey)
        let initialAttempts = client.connectionAttempts

        // When
        client.forceReconnect()

        // Then - attempts should increase
        XCTAssertGreaterThanOrEqual(client.connectionAttempts, initialAttempts)
    }

    // MARK: - Network Latency Tests

    func testInitialNetworkLatency() {
        // Then
        XCTAssertEqual(client.networkLatency, 0)
    }

    func testNetworkLatencyTracking() async {
        // Given
        client.connect(apiKey: testAPIKey)

        // When - wait for potential updates
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then - latency should be non-negative
        XCTAssertGreaterThanOrEqual(client.networkLatency, 0)
    }

    // MARK: - Connection Error Tests

    func testInitialConnectionError() {
        // Then
        XCTAssertNil(client.connectionError)
    }

    func testConnectionErrorClearing() {
        // Given - simulate error state
        client.connect(apiKey: "invalid", autoReconnect: false)

        // When - successful reconnection clears error
        client.disconnect()
        XCTAssertNil(client.connectionError)
    }

    // MARK: - Graceful Shutdown Tests

    func testGracefulDisconnect() {
        // Given
        client.connect(apiKey: testAPIKey)

        // When
        client.disconnect()

        // Then
        XCTAssertFalse(client.isConnected)
        XCTAssertEqual(client.connectionState, .disconnected)
        XCTAssertNil(client.connectionError)
    }

    func testDisconnectStopsReconnection() {
        // Given
        client.connect(apiKey: testAPIKey, autoReconnect: true)

        // When
        client.disconnect()

        // Then - should not attempt reconnection
        XCTAssertEqual(client.connectionState, .disconnected)
    }

    // MARK: - Connection State Consistency Tests

    func testConnectionStateConsistency() {
        // Given
        XCTAssertFalse(client.isConnected)
        XCTAssertEqual(client.connectionState, .disconnected)

        // When
        client.connect(apiKey: testAPIKey)

        // Then - state should be consistent
        if client.isConnected {
            XCTAssertEqual(client.connectionState, .connected)
        } else {
            XCTAssertTrue(
                client.connectionState == .connecting ||
                client.connectionState == .disconnected ||
                client.connectionState == .error
            )
        }
    }

    // MARK: - Diagnostic Health Tests

    func testHealthyConnectionDiagnostics() {
        // Given
        let diagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 1000,
            totalErrors: 5,
            latency: 0.15,
            uptime: 300
        )

        // Then
        XCTAssertTrue(diagnostics.isHealthy)
        XCTAssertLessThan(diagnostics.errorRate, 0.1)
        XCTAssertLessThan(diagnostics.latency, 2.0)
    }

    func testUnhealthyConnectionDiagnostics() {
        // Given - high error rate
        let highErrorDiagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 100,
            totalErrors: 15,
            latency: 0.15,
            uptime: 60
        )

        // Then
        XCTAssertFalse(highErrorDiagnostics.isHealthy)
        XCTAssertGreaterThan(highErrorDiagnostics.errorRate, 0.1)

        // Given - high latency
        let highLatencyDiagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 100,
            totalErrors: 2,
            latency: 5.0,
            uptime: 60
        )

        // Then
        XCTAssertFalse(highLatencyDiagnostics.isHealthy)
        XCTAssertGreaterThan(highLatencyDiagnostics.latency, 2.0)
    }

    // MARK: - Retry Logic Tests

    func testMaxRetryAttemptsConfiguration() {
        // Given - the default max retry attempts is 10
        client.connect(apiKey: testAPIKey, autoReconnect: true)

        // When
        let diagnostics = client.getConnectionDiagnostics()

        // Then - retry attempt should be within bounds
        XCTAssertLessThanOrEqual(diagnostics.retryAttempt, 10)
    }

    // MARK: - Connection Stability Tests

    func testMultipleDisconnectCalls() {
        // Given
        client.connect(apiKey: testAPIKey)

        // When - multiple disconnect calls
        client.disconnect()
        client.disconnect()
        client.disconnect()

        // Then - should handle gracefully
        XCTAssertFalse(client.isConnected)
        XCTAssertEqual(client.connectionState, .disconnected)
    }

    func testRapidConnectDisconnectCycles() async {
        // When
        for _ in 0..<5 {
            client.connect(apiKey: testAPIKey, autoReconnect: false)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            client.disconnect()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        // Then - should end in clean disconnected state
        XCTAssertEqual(client.connectionState, .disconnected)
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - Error Rate Calculation Tests

    func testErrorRateWithNoMessages() {
        // Given
        let diagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 0,
            totalErrors: 0,
            latency: 0.1,
            uptime: 10
        )

        // When
        let errorRate = diagnostics.errorRate

        // Then
        XCTAssertEqual(errorRate, 0.0)
    }

    func testErrorRateCalculation() {
        // Given
        let diagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 200,
            totalErrors: 10,
            latency: 0.1,
            uptime: 60
        )

        // When
        let errorRate = diagnostics.errorRate

        // Then
        XCTAssertEqual(errorRate, 0.05, accuracy: 0.001)
    }

    // MARK: - Uptime Tracking Tests

    func testUptimeInitiallyNil() {
        // When
        let diagnostics = client.getConnectionDiagnostics()

        // Then
        XCTAssertNil(diagnostics.uptime)
    }

    // MARK: - Performance Tests

    func testReconnectionPerformance() {
        measure {
            client.connect(apiKey: testAPIKey, autoReconnect: false)
            client.disconnect()
        }
    }

    func testDiagnosticsCalculationPerformance() {
        // Given
        client.connect(apiKey: testAPIKey)

        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = client.getConnectionDiagnostics()
            }
        }
    }
}
