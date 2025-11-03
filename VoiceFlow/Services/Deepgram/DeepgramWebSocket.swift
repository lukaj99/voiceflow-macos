import Foundation
import Starscream

/// Manages WebSocket connection lifecycle with enhanced reliability
@MainActor
public class DeepgramWebSocket: NSObject {

    // MARK: - Properties

    private var webSocket: WebSocket?
    private var apiKey: String?
    private var currentModel: DeepgramModel = .general

    // Reconnection state
    private var reconnectTimer: Timer?
    private var currentRetryAttempt = 0
    private let maxRetryAttempts = 10
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // Health monitoring
    private var healthCheckTimer: Timer?
    private var lastMessageReceived = Date()

    // Connection state
    public var shouldAutoReconnect = false
    public var isConnected = false

    // Callbacks
    public var onConnectionStateChange: ((ConnectionState) -> Void)?
    public var onMessageReceived: ((String) -> Void)?
    public var onError: ((String) -> Void)?

    // MARK: - Initialization

    public override init() {
        super.init()
        print("🌐 DeepgramWebSocket initialized with auto-reconnection")
    }

    // MARK: - Public Methods

    /// Update the current model configuration
    public func setModel(_ model: DeepgramModel) {
        currentModel = model
    }

    /// Connect to Deepgram WebSocket with enhanced reliability
    public func connect(apiKey: String, model: DeepgramModel, autoReconnect: Bool, onConnected: @escaping () -> Void) {
        print("🌐 Connecting to Deepgram WebSocket...")

        self.apiKey = apiKey
        self.currentModel = model
        self.shouldAutoReconnect = autoReconnect

        // Cancel any existing timers
        reconnectTimer?.invalidate()

        // Build WebSocket URL
        guard let url = buildWebSocketURL() else {
            onError?("Invalid WebSocket URL configuration")
            return
        }

        // Create WebSocket request with authentication
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        // Create and configure WebSocket
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self

        // Enhanced connection options
        var urlRequest = request
        urlRequest.setValue("websocket", forHTTPHeaderField: "Upgrade")
        urlRequest.setValue("Upgrade", forHTTPHeaderField: "Connection")

        webSocket?.connect()

        let attemptInfo = currentRetryAttempt > 0 ? " (attempt \(currentRetryAttempt + 1)/\(maxRetryAttempts))" : ""
        print("🔗 Enhanced WebSocket connection initiated\(attemptInfo): \(url)")

        // Set connection timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.checkConnectionTimeout()
        }
    }

    /// Disconnect from WebSocket
    public func disconnect() {
        print("🌐 Disconnecting WebSocket...")

        shouldAutoReconnect = false

        // Cancel timers
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        // Send close message
        sendCloseMessage()

        // Disconnect
        webSocket?.disconnect()
        webSocket = nil

        isConnected = false
        currentRetryAttempt = 0

        print("✅ WebSocket disconnected")
    }

    /// Send audio data through WebSocket
    public func sendAudioData(_ data: Data) {
        guard isConnected, let webSocket = webSocket else {
            print("⚠️ Cannot send audio: not connected")
            return
        }

        webSocket.write(data: data)
        print("📡 Sent \(data.count) bytes of audio data")
    }

    /// Force reconnection
    public func forceReconnect() {
        guard let apiKey = apiKey else {
            print("⚠️ Cannot reconnect: no API key stored")
            return
        }

        print("🔄 Forcing reconnection...")

        webSocket?.disconnect()
        webSocket = nil
        isConnected = false
        currentRetryAttempt = 0

        connect(apiKey: apiKey, model: currentModel, autoReconnect: shouldAutoReconnect) { [weak self] in
            self?.onConnectionStateChange?(.connected)
        }
    }

    /// Update last message received timestamp
    public func updateLastMessageReceived() {
        lastMessageReceived = Date()
    }

    /// Get current retry attempt
    public func getCurrentRetryAttempt() -> Int {
        return currentRetryAttempt
    }

    /// Reset retry attempt counter
    public func resetRetryAttempt() {
        currentRetryAttempt = 0
    }

    // MARK: - Private Methods

    private func sendCloseMessage() {
        guard let webSocket = webSocket else { return }

        let closeMessage = ["type": "CloseStream"]
        if let data = try? JSONSerialization.data(withJSONObject: closeMessage),
           let jsonString = String(data: data, encoding: .utf8) {
            webSocket.write(string: jsonString)
            print("📤 Sent close stream message")
        }
    }

    private func buildWebSocketURL() -> URL? {
        guard var urlComponents = URLComponents(string: "wss://api.deepgram.com/v1/listen") else {
            return nil
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: currentModel.rawValue),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "diarize", value: "false"),
            URLQueryItem(name: "filler_words", value: "false"),
            URLQueryItem(name: "endpointing", value: "300")
        ]

        return urlComponents.url
    }

    private func scheduleReconnection() {
        guard shouldAutoReconnect else { return }

        currentRetryAttempt += 1

        // Calculate exponential backoff
        let delay = min(baseRetryDelay * pow(2.0, Double(currentRetryAttempt - 1)), maxRetryDelay)
        let jitter = Double.random(in: 0...0.1) * delay
        let finalDelay = delay + jitter

        print("🔄 Scheduling reconnection attempt \(currentRetryAttempt)/\(maxRetryAttempts) in \(String(format: "%.1f", finalDelay))s...")

        onConnectionStateChange?(.reconnecting)

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: finalDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let apiKey = self.apiKey else { return }
                self.connect(apiKey: apiKey, model: self.currentModel, autoReconnect: true) {
                    self.onConnectionStateChange?(.connected)
                }
            }
        }
    }

    private func checkConnectionTimeout() {
        if !isConnected {
            handleConnectionFailure("Connection timeout")
        }
    }

    private func handleConnectionFailure(_ reason: String) {
        isConnected = false
        onError?(reason)
        onConnectionStateChange?(.error)

        print("❌ Connection failed: \(reason)")

        if shouldAutoReconnect && currentRetryAttempt < maxRetryAttempts {
            scheduleReconnection()
        } else if currentRetryAttempt >= maxRetryAttempts {
            print("💔 Max retry attempts reached. Giving up.")
            shouldAutoReconnect = false
        }
    }

    private func setupHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performHealthCheck()
            }
        }
    }

    private func performHealthCheck() {
        guard isConnected else { return }

        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageReceived)

        if timeSinceLastMessage > 60.0 {
            print("🏥 Health check failed: No messages received in \(String(format: "%.1f", timeSinceLastMessage))s")

            if shouldAutoReconnect {
                handleConnectionFailure("Connection appears stale")
            }
        } else {
            print("🏥 Health check passed: Last message \(String(format: "%.1f", timeSinceLastMessage))s ago")
        }
    }
}

// MARK: - WebSocketDelegate

extension DeepgramWebSocket: WebSocketDelegate {

    nonisolated public func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        // Group related events to reduce complexity
        handleWebSocketEvent(event)
    }

    nonisolated private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected:
            handleConnectedEvent()
        case .disconnected(let reason, let code):
            handleDisconnectedEvent(reason: reason, code: code)
        case .text(let string):
            handleTextEvent(string: string)
        case .binary(let data):
            handleBinaryEvent(data: data)
        case .error(let error):
            handleErrorEvent(error: error)
        case .cancelled, .peerClosed:
            handleConnectionClosedEvent()
        case .reconnectSuggested, .viabilityChanged, .ping, .pong:
            handleDiagnosticEvent(event)
        }
    }

    nonisolated private func handleConnectionClosedEvent() {
        Task { @MainActor [weak self] in
            self?.isConnected = false
        }
    }

    nonisolated private func handleDiagnosticEvent(_ event: WebSocketEvent) {
        // Log diagnostic events without state changes
        Task { @MainActor in
            switch event {
            case .reconnectSuggested(let shouldReconnect):
                print("🔄 Reconnect suggested: \(shouldReconnect)")
            case .viabilityChanged(let isViable):
                print("📡 Connection viability changed: \(isViable)")
            case .ping(let data):
                print("🏓 Received ping: \(data?.count ?? 0) bytes")
            case .pong(let data):
                print("🏓 Received pong: \(data?.count ?? 0) bytes")
            default:
                break
            }
        }
    }

    nonisolated private func handleConnectedEvent() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("✅ WebSocket connected with enhanced monitoring")

            self.isConnected = true
            self.lastMessageReceived = Date()
            self.onConnectionStateChange?(.connected)

            if self.currentRetryAttempt > 0 {
                print("🎉 Connection recovered after \(self.currentRetryAttempt) attempts")
                self.currentRetryAttempt = 0
            }

            self.setupHealthMonitoring()
        }
    }

    nonisolated private func handleDisconnectedEvent(reason: String, code: UInt16) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("🔌 WebSocket disconnected: \(reason) with code: \(code)")

            self.isConnected = false

            if code == 1000 {
                self.onConnectionStateChange?(.disconnected)
            } else {
                let errorMsg = "Unexpected disconnection: \(reason) (code: \(code))"
                print("⚠️ \(errorMsg)")

                if self.shouldAutoReconnect {
                    self.handleConnectionFailure(errorMsg)
                } else {
                    self.onConnectionStateChange?(.error)
                    self.onError?(errorMsg)
                }
            }
        }
    }

    nonisolated private func handleTextEvent(string: String) {
        Task { @MainActor [weak self] in
            self?.updateLastMessageReceived()
            self?.onMessageReceived?(string)
        }
    }

    nonisolated private func handleBinaryEvent(data: Data) {
        Task { @MainActor in
            print("📦 Received unexpected binary data: \(data.count) bytes")
        }
    }

    nonisolated private func handleErrorEvent(error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let errorMsg = error?.localizedDescription ?? "Unknown WebSocket error"
            print("❌ WebSocket error: \(errorMsg)")

            self.isConnected = false

            if self.shouldAutoReconnect {
                self.handleConnectionFailure("WebSocket error: \(errorMsg)")
            } else {
                self.onConnectionStateChange?(.error)
                self.onError?(errorMsg)
            }
        }
    }

    nonisolated private func handleCancelledEvent() {
        Task { @MainActor [weak self] in
            print("🚫 WebSocket cancelled")
            self?.isConnected = false
        }
    }

    nonisolated private func handleReconnectSuggestedEvent(shouldReconnect: Bool) {
        Task { @MainActor in
            print("🔄 Reconnect suggested: \(shouldReconnect)")
        }
    }

    nonisolated private func handleViabilityChangedEvent(isViable: Bool) {
        Task { @MainActor in
            print("📡 Connection viability changed: \(isViable)")
        }
    }

    nonisolated private func handlePeerClosedEvent() {
        Task { @MainActor [weak self] in
            print("👋 WebSocket peer closed")
            self?.isConnected = false
        }
    }

    nonisolated private func handlePingEvent(data: Data?) {
        Task { @MainActor in
            print("🏓 Received ping: \(data?.count ?? 0) bytes")
        }
    }

    nonisolated private func handlePongEvent(data: Data?) {
        Task { @MainActor in
            print("🏓 Received pong: \(data?.count ?? 0) bytes")
        }
    }
}
