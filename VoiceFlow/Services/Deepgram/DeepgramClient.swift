import Foundation

/// Enhanced Deepgram WebSocket client with automatic reconnection and exponential backoff
/// Following 2025 reliability and resilience best practices
///
/// This is the main coordinator that orchestrates:
/// - DeepgramWebSocket: Connection management
/// - DeepgramResponseParser: Message parsing
/// - DeepgramModels: Data structures and types
@MainActor
public class DeepgramClient: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var connectionError: String?
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var connectionAttempts: Int = 0
    @Published public var networkLatency: TimeInterval = 0

    // MARK: - Private Properties
    private var webSocketManager: DeepgramWebSocket
    private var responseParser: DeepgramResponseParser
    private var apiKey: String?
    private var lastAutoReconnectValue = false // Track user's autoReconnect preference
    private var connectionStartTime: Date?
    private var totalMessages = 0

    // MARK: - Delegate
    public weak var delegate: (any DeepgramClientDelegate)? {
        didSet {
            responseParser.updateDelegate(delegate)
        }
    }

    // MARK: - Model Configuration
    public var currentModel: DeepgramModel = .general {
        didSet {
            webSocketManager.setModel(currentModel)
        }
    }

    // MARK: - Initialization
    public override init() {
        // Initialize components
        webSocketManager = DeepgramWebSocket()
        responseParser = DeepgramResponseParser(delegate: nil, client: nil)

        super.init()

        // Complete parser initialization
        responseParser = DeepgramResponseParser(delegate: delegate, client: self)

        // Setup callbacks
        setupWebSocketCallbacks()

        print("🌐 Enhanced DeepgramClient initialized with modular architecture")
    }

    // MARK: - Public Methods

    /// Update the Deepgram transcription model with automatic reconnection.
    ///
    /// Changes the active Deepgram Nova-3 model used for transcription. If currently
    /// connected, automatically disconnects and reconnects with the new model configuration.
    ///
    /// Available models:
    /// - General (Nova-3): Best for general conversation and business speech
    /// - Medical (Nova-3): Optimized for medical terminology and clinical notes
    /// - Enhanced (Nova-3): Enhanced accuracy for technical and specialized content
    ///
    /// ## Usage Example
    /// ```swift
    /// await client.setModel(.medical)
    /// // Automatically reconnects with medical model
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1) + reconnection overhead if connected
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter model: The Deepgram model to use for transcription
    /// - Note: Triggers automatic reconnection if currently connected
    /// - SeeAlso: `DeepgramModel`, `connect(apiKey:autoReconnect:)`
    public func setModel(_ model: DeepgramModel) {
        guard model != currentModel else { return }

        let wasConnected = isConnected
        let currentAPIKey = apiKey

        currentModel = model
        print("🧠 Deepgram model changed to: \(model.displayName)")

        // If currently connected, reconnect with new model (preserve autoReconnect preference)
        if wasConnected, let apiKey = currentAPIKey {
            print("🔄 Reconnecting with new model...")
            let shouldAutoReconnect = lastAutoReconnectValue // Preserve user's preference
            disconnect()

            // Small delay before reconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connect(apiKey: apiKey, autoReconnect: shouldAutoReconnect)
            }
        }
    }

    /// Connect to Deepgram's real-time transcription service with enhanced reliability.
    ///
    /// Establishes a WebSocket connection to Deepgram's API with automatic reconnection
    /// and exponential backoff for maximum reliability. Connection includes:
    /// - Authentication via API key
    /// - Configurable transcription parameters (language, sample rate, etc.)
    /// - Health monitoring and automatic recovery
    /// - Connection timeout protection (15s)
    ///
    /// ## Usage Example
    /// ```swift
    /// let client = DeepgramClient()
    /// client.delegate = self
    /// client.connect(apiKey: "YOUR_API_KEY", autoReconnect: true)
    /// // Connection established, ready to stream audio
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1) for initialization
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    /// - Connection timeout: 15 seconds
    ///
    /// - Parameters:
    ///   - apiKey: Deepgram API key for authentication
    ///   - autoReconnect: Enable automatic reconnection on failure (default: true)
    ///
    /// - Note: Uses exponential backoff for reconnection attempts (max 10 attempts)
    /// - SeeAlso: `disconnect()`, `DeepgramClientDelegate`, `connectionState`
    public func connect(apiKey: String, autoReconnect: Bool = true) {
        print("🌐 Connecting to Deepgram with enhanced reliability...")

        self.apiKey = apiKey
        self.lastAutoReconnectValue = autoReconnect // Store user's preference
        connectionError = nil
        connectionStartTime = Date()
        connectionAttempts += 1

        webSocketManager.connect(apiKey: apiKey, model: currentModel, autoReconnect: autoReconnect) { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
                self?.connectionState = .connected
            }
        }
    }

    /// Gracefully disconnect from Deepgram service.
    ///
    /// Performs a clean shutdown of the WebSocket connection:
    /// - Sends close message to server
    /// - Cancels pending reconnection attempts
    /// - Stops health monitoring
    /// - Resets connection state
    /// - Cleans up resources
    ///
    /// ## Usage Example
    /// ```swift
    /// client.disconnect()
    /// // Connection closed gracefully
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: Safe to call multiple times; subsequent calls are no-ops
    /// - SeeAlso: `connect(apiKey:autoReconnect:)`, `forceReconnect()`
    public func disconnect() {
        print("🌐 Gracefully disconnecting from Deepgram...")

        webSocketManager.disconnect()

        isConnected = false
        connectionState = .disconnected
        connectionError = nil

        print("✅ Gracefully disconnected from Deepgram")
    }

    /// Send audio data to Deepgram for real-time transcription.
    ///
    /// Streams audio data to the WebSocket connection for processing. Audio should be:
    /// - Format: Linear PCM (linear16)
    /// - Sample rate: 16000 Hz
    /// - Channels: 1 (mono)
    /// - Encoding: 16-bit
    ///
    /// ## Usage Example
    /// ```swift
    /// let audioBuffer: Data = // ... captured audio
    /// client.sendAudioData(audioBuffer)
    /// // Audio sent for transcription
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1) for queuing
    /// - Memory usage: O(n) where n = data size
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter data: Raw audio data in the correct format
    /// - Note: Silently fails if not connected; check isConnected before sending
    /// - SeeAlso: `isConnected`, `DeepgramClientDelegate`
    public func sendAudioData(_ data: Data) {
        guard isConnected else {
            print("⚠️ Cannot send audio: not connected")
            return
        }

        webSocketManager.sendAudioData(data)
        totalMessages += 1
    }

    /// Get connection diagnostics for monitoring and debugging.
    ///
    /// Returns comprehensive connection health information including:
    /// - Current connection state
    /// - Total connection attempts
    /// - Current retry attempt number
    /// - Message and error counts
    /// - Network latency
    /// - Connection uptime
    ///
    /// ## Usage Example
    /// ```swift
    /// let diagnostics = client.getConnectionDiagnostics()
    /// print("State: \(diagnostics.state)")
    /// print("Latency: \(diagnostics.latency)ms")
    /// print("Healthy: \(diagnostics.isHealthy)")
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Returns: Connection diagnostics snapshot
    /// - SeeAlso: `ConnectionDiagnostics`, `connectionState`
    public func getConnectionDiagnostics() -> ConnectionDiagnostics {
        return ConnectionDiagnostics(
            state: connectionState,
            attempts: connectionAttempts,
            retryAttempt: webSocketManager.getCurrentRetryAttempt(),
            totalMessages: totalMessages,
            totalErrors: responseParser.totalErrors,
            latency: responseParser.networkLatency,
            uptime: connectionStartTime.map { Date().timeIntervalSince($0) }
        )
    }

    /// Force immediate reconnection to Deepgram service.
    ///
    /// Manually triggers a reconnection cycle, bypassing normal retry logic.
    /// Useful for:
    /// - Testing connection recovery
    /// - Manual error recovery
    /// - Switching network interfaces
    /// - Recovering from stale connections
    ///
    /// ## Usage Example
    /// ```swift
    /// // Network changed, force reconnect
    /// client.forceReconnect()
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: Resets retry counter to allow fresh connection attempt
    /// - SeeAlso: `connect(apiKey:autoReconnect:)`, `disconnect()`
    public func forceReconnect() {
        guard apiKey != nil else {
            print("⚠️ Cannot reconnect: no API key stored")
            return
        }

        print("🔄 Forcing reconnection...")
        webSocketManager.forceReconnect()
    }

    // MARK: - Private Methods

    private func setupWebSocketCallbacks() {
        webSocketManager.onConnectionStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
                self?.isConnected = (state == .connected)
            }
        }

        webSocketManager.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                guard let self = self else { return }
                let newRetryAttempt = self.responseParser.handleTextMessage(message, currentRetryAttempt: self.webSocketManager.getCurrentRetryAttempt())
                if newRetryAttempt == 0 {
                    self.webSocketManager.resetRetryAttempt()
                }
                self.networkLatency = self.responseParser.networkLatency
            }
        }

        webSocketManager.onError = { [weak self] error in
            Task { @MainActor in
                self?.connectionError = error
            }
        }
    }
}
