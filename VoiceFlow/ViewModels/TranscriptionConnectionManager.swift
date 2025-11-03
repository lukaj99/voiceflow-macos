import Foundation

/// Manages connection state and reliability for transcription services
/// Single Responsibility: Connection management, retry logic, and health monitoring
public actor TranscriptionConnectionManager {

    // MARK: - Types

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed(any Error)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        var canAttemptConnection: Bool {
            switch self {
            case .disconnected, .failed: return true
            case .connecting, .connected, .reconnecting: return false
            }
        }
    }

    public struct ConnectionMetrics {
        public let attemptCount: Int
        public let successfulConnections: Int
        public let averageConnectionTime: TimeInterval
        public let lastConnectionTime: Date?
        public let uptime: TimeInterval

        public var successRate: Double {
            attemptCount > 0 ? Double(successfulConnections) / Double(attemptCount) : 0.0
        }
    }

    // MARK: - Properties

    private var currentState: ConnectionState = .disconnected
    private var connectionAttempts: Int = 0
    private var successfulConnections: Int = 0
    private var connectionTimes: [TimeInterval] = []
    private var lastConnectionTime: Date?
    private var connectionStartTime: Date?

    private let maxRetryAttempts: Int = 3
    private let retryDelay: TimeInterval = 2.0
    private let connectionTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    public init() {
        print("🔗 TranscriptionConnectionManager initialized")
    }

    // MARK: - Public Interface

    /// Attempt to connect to transcription service with retry logic
    public func connect(apiKey: String, client: DeepgramClient) async -> Bool {
        guard currentState.canAttemptConnection else {
            print("⚠️ Connection attempt ignored - already connecting/connected")
            return currentState.isConnected
        }

        print("🔗 Attempting to connect to transcription service...")
        currentState = .connecting
        connectionAttempts += 1
        connectionStartTime = Date()

        for attempt in 1...maxRetryAttempts {
            let connected = await attemptConnection(apiKey: apiKey, client: client, attempt: attempt)

            if connected {
                currentState = .connected
                successfulConnections += 1
                lastConnectionTime = Date()

                if let startTime = connectionStartTime {
                    let connectionTime = Date().timeIntervalSince(startTime)
                    connectionTimes.append(connectionTime)
                    print("✅ Connected successfully in \(String(format: "%.2f", connectionTime))s")
                }

                return true
            }

            if attempt < maxRetryAttempts {
                print("🔄 Retrying connection in \(retryDelay)s... (attempt \(attempt + 1)/\(maxRetryAttempts))")
                currentState = .reconnecting
                try? await Task.sleep(for: .seconds(retryDelay))
            }
        }

        let error = ConnectionError.maxRetriesExceeded
        currentState = .failed(error)
        print("❌ Connection failed after \(maxRetryAttempts) attempts")

        return false
    }

    /// Disconnect from transcription service
    public func disconnect(client: DeepgramClient) async {
        await client.disconnect()
        currentState = .disconnected
        connectionStartTime = nil
        print("🔌 Disconnected from transcription service")
    }

    /// Get current connection state
    public func getConnectionState() -> ConnectionState {
        return currentState
    }

    /// Get connection metrics and statistics
    public func getConnectionMetrics() -> ConnectionMetrics {
        let averageTime = connectionTimes.isEmpty ? 0.0 : connectionTimes.reduce(0, +) / Double(connectionTimes.count)
        let uptime = lastConnectionTime?.timeIntervalSinceNow ?? 0.0

        return ConnectionMetrics(
            attemptCount: connectionAttempts,
            successfulConnections: successfulConnections,
            averageConnectionTime: averageTime,
            lastConnectionTime: lastConnectionTime,
            uptime: abs(uptime)
        )
    }

    /// Check connection health
    public func checkConnectionHealth(client: DeepgramClient) async -> Bool {
        // Simple health check - more sophisticated checks can be added
        return await client.connectionState == .connected
    }

    /// Reset connection statistics
    public func resetStatistics() {
        connectionAttempts = 0
        successfulConnections = 0
        connectionTimes.removeAll()
        lastConnectionTime = nil
        print("📊 Connection statistics reset")
    }

    // MARK: - Private Methods

    /// Attempt a single connection
    private func attemptConnection(apiKey: String, client: DeepgramClient, attempt: Int) async -> Bool {
        print("🔗 Connection attempt \(attempt)/\(maxRetryAttempts)")

        // Connect to Deepgram
        await client.connect(apiKey: apiKey, autoReconnect: false) // We handle retry logic ourselves

        // Wait for connection with timeout
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < connectionTimeout {
            switch await client.connectionState {
            case .connected:
                return true
            case .error:
                print("❌ Connection attempt \(attempt) failed with error")
                return false
            default:
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        print("⏰ Connection attempt \(attempt) timed out after \(connectionTimeout)s")
        return false
    }
}

// MARK: - Connection Errors

public enum ConnectionError: LocalizedError {
    case maxRetriesExceeded
    case connectionTimeout
    case invalidAPIKey
    case networkUnavailable
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Failed to connect after maximum retry attempts"
        case .connectionTimeout:
            return "Connection attempt timed out"
        case .invalidAPIKey:
            return "Invalid or expired API key"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .serviceUnavailable:
            return "Transcription service temporarily unavailable"
        }
    }
}
