import XCTest
@testable import VoiceFlow

/// Comprehensive tests for DeepgramClient WebSocket functionality
@MainActor
final class DeepgramClientTests: XCTestCase {

    private var client: DeepgramClient!
    private var mockDelegate: MockDeepgramDelegate!
    private let testAPIKey = "test-api-key-12345"

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        client = DeepgramClient()
        mockDelegate = MockDeepgramDelegate()
        client.delegate = mockDelegate
    }

    @MainActor
    override func tearDown() async throws {
        if client.isConnected {
            client.disconnect()
        }
        client = nil
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDeepgramClientInitialization() {
        // Then
        XCTAssertFalse(client.isConnected)
        XCTAssertEqual(client.connectionState, .disconnected)
        XCTAssertNil(client.connectionError)
        XCTAssertEqual(client.connectionAttempts, 0)
        XCTAssertEqual(client.networkLatency, 0)
    }

    // MARK: - Connection State Tests

    func testInitialConnectionState() {
        // Then
        XCTAssertEqual(client.connectionState, .disconnected)
        XCTAssertFalse(client.isConnected)
    }

    func testConnectionStateTransitions() {
        // Given
        XCTAssertEqual(client.connectionState, .disconnected)

        // When - initiate connection
        client.connect(apiKey: testAPIKey, autoReconnect: false)

        // Then - should transition to connecting
        XCTAssertTrue(
            client.connectionState == .connecting || client.connectionState == .connected,
            "Connection state should be connecting or connected, got \(client.connectionState)"
        )
        XCTAssertEqual(client.connectionAttempts, 1)
    }

    // MARK: - Model Configuration Tests

    func testDefaultModel() {
        // Then
        XCTAssertEqual(client.currentModel, .general)
    }

    func testSetModelWhenDisconnected() {
        // Given
        XCTAssertEqual(client.currentModel, .general)

        // When
        client.setModel(.medical)

        // Then
        XCTAssertEqual(client.currentModel, .medical)
    }

    func testModelDisplayNames() {
        // Given/When/Then
        XCTAssertEqual(DeepgramModel.general.displayName, "General (Nova-3)")
        XCTAssertEqual(DeepgramModel.medical.displayName, "Medical (Nova-3)")
        XCTAssertEqual(DeepgramModel.enhanced.displayName, "Enhanced (Nova-3)")
    }

    func testModelDescriptions() {
        // Given/When/Then
        XCTAssertTrue(DeepgramModel.general.description.contains("general conversation"))
        XCTAssertTrue(DeepgramModel.medical.description.contains("medical terminology"))
        XCTAssertTrue(DeepgramModel.enhanced.description.contains("Enhanced accuracy"))
    }

    func testModelSpecialization() {
        // Given/When/Then
        XCTAssertFalse(DeepgramModel.general.isSpecialized)
        XCTAssertTrue(DeepgramModel.medical.isSpecialized)
        XCTAssertTrue(DeepgramModel.enhanced.isSpecialized)
    }

    // MARK: - Disconnect Tests

    func testDisconnectWhenNotConnected() {
        // Given
        XCTAssertFalse(client.isConnected)

        // When
        client.disconnect()

        // Then - should handle gracefully
        XCTAssertFalse(client.isConnected)
        XCTAssertEqual(client.connectionState, .disconnected)
    }

    // MARK: - Audio Data Tests

    func testSendAudioDataWhenNotConnected() {
        // Given
        let audioData = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertFalse(client.isConnected)

        // When
        client.sendAudioData(audioData)

        // Then - should handle gracefully without crashing
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - Connection Diagnostics Tests

    func testConnectionDiagnosticsInitialState() {
        // When
        let diagnostics = client.getConnectionDiagnostics()

        // Then
        XCTAssertEqual(diagnostics.state, .disconnected)
        XCTAssertEqual(diagnostics.attempts, 0)
        XCTAssertEqual(diagnostics.retryAttempt, 0)
        XCTAssertEqual(diagnostics.totalMessages, 0)
        XCTAssertEqual(diagnostics.totalErrors, 0)
        XCTAssertEqual(diagnostics.latency, 0)
        XCTAssertNil(diagnostics.uptime)
    }

    func testConnectionDiagnosticsAfterConnectionAttempt() {
        // Given
        client.connect(apiKey: testAPIKey, autoReconnect: false)

        // When
        let diagnostics = client.getConnectionDiagnostics()

        // Then
        XCTAssertGreaterThan(diagnostics.attempts, 0)
    }

    func testConnectionDiagnosticsErrorRate() {
        // Given
        let diagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 5,
            retryAttempt: 0,
            totalMessages: 100,
            totalErrors: 5,
            latency: 0.15,
            uptime: 120
        )

        // When
        let errorRate = diagnostics.errorRate

        // Then
        XCTAssertEqual(errorRate, 0.05, accuracy: 0.001)
    }

    func testConnectionDiagnosticsIsHealthy() {
        // Given - healthy connection
        let healthyDiagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 1000,
            totalErrors: 5,
            latency: 0.5,
            uptime: 600
        )

        // Then
        XCTAssertTrue(healthyDiagnostics.isHealthy)

        // Given - unhealthy connection (high latency)
        let unhealthyLatencyDiagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 1000,
            totalErrors: 5,
            latency: 3.0,
            uptime: 600
        )

        // Then
        XCTAssertFalse(unhealthyLatencyDiagnostics.isHealthy)

        // Given - unhealthy connection (high error rate)
        let unhealthyErrorDiagnostics = ConnectionDiagnostics(
            state: .connected,
            attempts: 1,
            retryAttempt: 0,
            totalMessages: 100,
            totalErrors: 20,
            latency: 0.5,
            uptime: 600
        )

        // Then
        XCTAssertFalse(unhealthyErrorDiagnostics.isHealthy)
    }

    // MARK: - DeepgramResponse Tests

    func testDeepgramResponseDecoding() throws {
        // Given
        let json = """
        {
            "type": "Results",
            "channel_index": [0],
            "duration": 1.5,
            "start": 123456789.0,
            "is_final": true,
            "speech_final": true,
            "channel": {
                "alternatives": [
                    {
                        "transcript": "Hello world",
                        "confidence": 0.95,
                        "words": [
                            {
                                "word": "Hello",
                                "start": 0.0,
                                "end": 0.5,
                                "confidence": 0.97
                            },
                            {
                                "word": "world",
                                "start": 0.5,
                                "end": 1.0,
                                "confidence": 0.93
                            }
                        ]
                    }
                ]
            }
        }
        """

        // When
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

        // Then
        XCTAssertEqual(response.type, "Results")
        XCTAssertEqual(response.is_final, true)
        XCTAssertEqual(response.channel?.alternatives?.first?.transcript, "Hello world")
        XCTAssertEqual(response.channel?.alternatives?.first?.confidence, 0.95)
        XCTAssertEqual(response.channel?.alternatives?.first?.words?.count, 2)
    }

    func testDeepgramResponseWithMinimalData() throws {
        // Given
        let json = """
        {
            "type": "Results"
        }
        """

        // When
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

        // Then
        XCTAssertEqual(response.type, "Results")
        XCTAssertNil(response.channel)
        XCTAssertNil(response.is_final)
    }

    // MARK: - ConnectionState Tests

    func testConnectionStateColors() {
        // Given/When/Then
        XCTAssertEqual(DeepgramClient.ConnectionState.disconnected.color, "gray")
        XCTAssertEqual(DeepgramClient.ConnectionState.connecting.color, "orange")
        XCTAssertEqual(DeepgramClient.ConnectionState.connected.color, "green")
        XCTAssertEqual(DeepgramClient.ConnectionState.reconnecting.color, "yellow")
        XCTAssertEqual(DeepgramClient.ConnectionState.error.color, "red")
    }

    func testConnectionStateCodable() throws {
        // Given
        let states: [DeepgramClient.ConnectionState] = [
            .disconnected, .connecting, .connected, .reconnecting, .error
        ]

        // When/Then
        for state in states {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(DeepgramClient.ConnectionState.self, from: encoded)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - Performance Tests

    func testConnectionDiagnosticsPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = client.getConnectionDiagnostics()
            }
        }
    }

    func testModelSwitchingPerformance() {
        measure {
            for _ in 0..<100 {
                client.setModel(.general)
                client.setModel(.medical)
                client.setModel(.enhanced)
            }
        }
    }

    func testDeepgramResponseDecodingPerformance() throws {
        // Given
        let json = """
        {
            "type": "Results",
            "is_final": true,
            "channel": {
                "alternatives": [{
                    "transcript": "Performance test transcript",
                    "confidence": 0.92
                }]
            }
        }
        """
        let data = json.data(using: .utf8)!

        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = try? JSONDecoder().decode(DeepgramResponse.self, from: data)
            }
        }
    }
}

// MARK: - Mock Delegate

@MainActor
private class MockDeepgramDelegate: DeepgramClientDelegate {
    var transcriptsReceived: [(String, Bool)] = []

    func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool) {
        transcriptsReceived.append((transcript, isFinal))
    }

    func reset() {
        transcriptsReceived.removeAll()
    }
}
