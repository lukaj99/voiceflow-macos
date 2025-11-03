import Foundation
import Starscream

/// Enhanced Deepgram WebSocket client with automatic reconnection and exponential backoff
/// Following 2025 reliability and resilience best practices
@MainActor
public class DeepgramClient: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var connectionError: String?
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var connectionAttempts: Int = 0
    @Published public var networkLatency: TimeInterval = 0
    
    // MARK: - Private Properties
    private var webSocket: WebSocket?
    private var apiKey: String?
    private var shouldAutoReconnect = false
    
    // Reconnection state
    private var reconnectTimer: Timer?
    private var currentRetryAttempt = 0
    private var maxRetryAttempts = 10
    private var baseRetryDelay: TimeInterval = 1.0
    private var maxRetryDelay: TimeInterval = 30.0
    
    // Health monitoring
    private var healthCheckTimer: Timer?
    private var lastMessageReceived = Date()
    private var connectionStartTime: Date?
    
    // Performance tracking
    private var messageSentTime: [String: Date] = [:]
    private var totalMessages = 0
    private var totalErrors = 0
    
    // MARK: - Delegate
    public weak var delegate: (any DeepgramClientDelegate)?
    
    // MARK: - Model Configuration
    public var currentModel: DeepgramModel = .general
    
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
        
        // If currently connected, reconnect with new model
        if wasConnected, let apiKey = currentAPIKey {
            print("🔄 Reconnecting with new model...")
            disconnect()
            
            // Small delay before reconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connect(apiKey: apiKey, autoReconnect: self.shouldAutoReconnect)
            }
        }
    }
    
    // MARK: - Types
    
    public enum ConnectionState: String, CaseIterable, Codable, Sendable {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
        case reconnecting = "Reconnecting"
        case error = "Error"
        
        public var color: String {
            switch self {
            case .disconnected: return "gray"
            case .connecting: return "orange"
            case .connected: return "green"
            case .reconnecting: return "yellow"
            case .error: return "red"
            }
        }
    }
    
    // MARK: - Initialization
    public override init() {
        super.init()
        print("🌐 Enhanced DeepgramClient initialized with auto-reconnection")
        // Note: Health monitoring will be setup when connecting
    }
    
    // MARK: - Public Methods

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
        self.shouldAutoReconnect = autoReconnect
        connectionError = nil
        connectionStartTime = Date()
        
        // Reset retry state for new connection attempt
        if connectionState != .reconnecting {
            currentRetryAttempt = 0
        }
        
        connectionAttempts += 1
        connectionState = currentRetryAttempt > 0 ? .reconnecting : .connecting
        
        // Cancel any existing timers
        reconnectTimer?.invalidate()
        
        // Build WebSocket URL with enhanced parameters
        guard let url = buildWebSocketURL() else {
            handleConnectionFailure("Invalid WebSocket URL configuration")
            return
        }
        
        // Create WebSocket request with authentication and timeouts
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0 // 10 second timeout
        
        // Create and configure WebSocket with enhanced settings
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
        
        // Disable auto-reconnection
        shouldAutoReconnect = false
        
        // Cancel any pending reconnection attempts
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // Stop health monitoring
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        // Send close message if connected
        if isConnected {
            sendCloseMessage()
        }
        
        // Disconnect WebSocket
        webSocket?.disconnect()
        webSocket = nil
        
        // Update state
        isConnected = false
        connectionState = .disconnected
        connectionError = nil
        currentRetryAttempt = 0
        
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
        guard isConnected, let webSocket = webSocket else {
            print("⚠️ Cannot send audio: not connected")
            return
        }
        
        webSocket.write(data: data)
        totalMessages += 1
        print("📡 Sent \(data.count) bytes of audio data")
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
            retryAttempt: currentRetryAttempt,
            totalMessages: totalMessages,
            totalErrors: totalErrors,
            latency: networkLatency,
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
        guard let apiKey = apiKey else {
            print("⚠️ Cannot reconnect: no API key stored")
            return
        }
        
        print("🔄 Forcing reconnection...")
        
        // Disconnect current connection
        webSocket?.disconnect()
        webSocket = nil
        isConnected = false
        
        // Reset retry count for forced reconnection
        currentRetryAttempt = 0
        
        // Reconnect
        connect(apiKey: apiKey, autoReconnect: shouldAutoReconnect)
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
    
    /// Build WebSocket URL with optimized parameters
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
            URLQueryItem(name: "endpointing", value: "300") // 300ms silence detection
        ]
        
        return urlComponents.url
    }
    
    /// Handle connection failure with proper error management
    private func handleConnectionFailure(_ reason: String) {
        totalErrors += 1
        connectionError = reason
        connectionState = .error
        isConnected = false
        
        print("❌ Connection failed: \(reason)")
        
        // Attempt reconnection if enabled
        if shouldAutoReconnect && currentRetryAttempt < maxRetryAttempts {
            scheduleReconnection()
        } else if currentRetryAttempt >= maxRetryAttempts {
            print("💔 Max retry attempts reached. Giving up.")
            connectionError = "Max retry attempts reached: \(reason)"
            shouldAutoReconnect = false
        }
    }
    
    /// Schedule reconnection with exponential backoff
    private func scheduleReconnection() {
        guard shouldAutoReconnect else { return }
        
        currentRetryAttempt += 1
        
        // Calculate exponential backoff delay
        let delay = min(baseRetryDelay * pow(2.0, Double(currentRetryAttempt - 1)), maxRetryDelay)
        let jitter = Double.random(in: 0...0.1) * delay // Add 10% jitter
        let finalDelay = delay + jitter
        
        print("🔄 Scheduling reconnection attempt \(currentRetryAttempt)/\(maxRetryAttempts) in \(String(format: "%.1f", finalDelay))s...")
        
        connectionState = .reconnecting
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: finalDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let apiKey = self.apiKey else { return }
                self.connect(apiKey: apiKey, autoReconnect: true)
            }
        }
    }
    
    /// Check for connection timeout
    private func checkConnectionTimeout() {
        if connectionState == .connecting || connectionState == .reconnecting {
            if !isConnected {
                handleConnectionFailure("Connection timeout")
            }
        }
    }
    
    /// Setup health monitoring system
    private func setupHealthMonitoring() {
        // Monitor connection health every 30 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performHealthCheck()
            }
        }
    }
    
    /// Perform connection health check
    private func performHealthCheck() {
        guard isConnected else { return }
        
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageReceived)
        
        // If no message received in 60 seconds, consider connection stale
        if timeSinceLastMessage > 60.0 {
            print("🏥 Health check failed: No messages received in \(String(format: "%.1f", timeSinceLastMessage))s")
            
            // Force reconnection if auto-reconnect is enabled
            if shouldAutoReconnect {
                handleConnectionFailure("Connection appears stale")
            }
        } else {
            print("🏥 Health check passed: Last message \(String(format: "%.1f", timeSinceLastMessage))s ago")
        }
    }
    
    private func handleTextMessage(_ text: String) {
        // Update last message received time for health monitoring
        lastMessageReceived = Date()
        
        print("📥 Received message: \(text)")
        
        guard let data = text.data(using: .utf8) else {
            print("❌ Failed to convert message to data")
            totalErrors += 1
            return
        }
        
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            // Reset retry attempts on successful message
            if currentRetryAttempt > 0 {
                print("✅ Connection recovered after \(currentRetryAttempt) attempts")
                currentRetryAttempt = 0
            }
            
            // Extract transcript if available
            if let channel = response.channel,
               let alternative = channel.alternatives?.first,
               let transcript = alternative.transcript,
               !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                let isFinal = response.is_final ?? false
                let confidence = alternative.confidence ?? 0.0
                
                print("📝 Transcript (\(isFinal ? "final" : "interim"), confidence: \(String(format: "%.2f", confidence))): \(transcript)")
                
                // Calculate latency if we have timing info
                if let start = response.start {
                    networkLatency = Date().timeIntervalSince1970 - start
                }
                
                Task { @MainActor in
                    delegate?.deepgramClient(self, didReceiveTranscript: transcript, isFinal: isFinal)
                }
            }
            
        } catch {
            print("❌ Failed to decode Deepgram response: \(error)")
            totalErrors += 1
        }
    }
}

// MARK: - WebSocketDelegate

extension DeepgramClient: WebSocketDelegate {
    
    nonisolated public func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        // Handle event synchronously to avoid Sendable issues
        switch event {
        case .connected(_):
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("✅ WebSocket connected with enhanced monitoring")
                
                self.isConnected = true
                self.connectionError = nil
                self.connectionState = .connected
                self.lastMessageReceived = Date()
                
                // Reset retry attempts on successful connection
                if self.currentRetryAttempt > 0 {
                    print("🎉 Connection recovered after \(self.currentRetryAttempt) attempts")
                    self.currentRetryAttempt = 0
                }
                
                // Start health monitoring
                self.setupHealthMonitoring()
            }
            
        case .disconnected(let reason, let code):
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("🔌 WebSocket disconnected: \(reason) with code: \(code)")
                
                self.isConnected = false
                
                // Handle different disconnect scenarios
                if code == 1000 { // Normal closure
                    self.connectionState = .disconnected
                    self.connectionError = nil
                } else {
                    // Unexpected disconnection - trigger reconnection
                    let errorMsg = "Unexpected disconnection: \(reason) (code: \(code))"
                    print("⚠️ \(errorMsg)")
                    
                    if self.shouldAutoReconnect {
                        self.handleConnectionFailure(errorMsg)
                    } else {
                        self.connectionState = .error
                        self.connectionError = errorMsg
                    }
                }
            }
            
        case .text(let string):
            Task { @MainActor [weak self] in
                self?.handleTextMessage(string)
            }
            
        case .binary(let data):
            Task { @MainActor in
                print("📦 Received unexpected binary data: \(data.count) bytes")
            }
            
        case .error(let error):
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let errorMsg = error?.localizedDescription ?? "Unknown WebSocket error"
                print("❌ WebSocket error: \(errorMsg)")
                
                self.isConnected = false
                
                if self.shouldAutoReconnect {
                    self.handleConnectionFailure("WebSocket error: \(errorMsg)")
                } else {
                    self.connectionState = .error
                    self.connectionError = errorMsg
                }
            }
            
        case .cancelled:
            Task { @MainActor [weak self] in
                print("🚫 WebSocket cancelled")
                self?.isConnected = false
            }
            
        case .reconnectSuggested(let shouldReconnect):
            Task { @MainActor in
                print("🔄 Reconnect suggested: \(shouldReconnect)")
            }
            
        case .viabilityChanged(let isViable):
            Task { @MainActor in
                print("📡 Connection viability changed: \(isViable)")
            }
            
        case .peerClosed:
            Task { @MainActor [weak self] in
                print("👋 WebSocket peer closed")
                self?.isConnected = false
            }
            
        case .ping(let data):
            Task { @MainActor in
                print("🏓 Received ping: \(data?.count ?? 0) bytes")
            }
            
        case .pong(let data):
            Task { @MainActor in
                print("🏓 Received pong: \(data?.count ?? 0) bytes")
            }
        }
    }
}

// MARK: - Model Selection

/// Available Deepgram Nova-3 models
public enum DeepgramModel: String, CaseIterable {
    case general = "nova-3"
    case medical = "nova-3-medical"
    case enhanced = "nova-3-enhanced"
    
    public var displayName: String {
        switch self {
        case .general: return "General (Nova-3)"
        case .medical: return "Medical (Nova-3)"
        case .enhanced: return "Enhanced (Nova-3)"
        }
    }
    
    public var description: String {
        switch self {
        case .general: return "Best for general conversation, business, and everyday speech"
        case .medical: return "Optimized for medical terminology, clinical notes, and healthcare"
        case .enhanced: return "Enhanced accuracy for technical, legal, and specialized content"
        }
    }
    
    public var isSpecialized: Bool {
        return self != .general
    }
}

// MARK: - Delegate Protocol

public protocol DeepgramClientDelegate: AnyObject {
    func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool)
}

// MARK: - Deepgram Response Models

public struct DeepgramResponse: Codable {
    public let type: String?
    public let channel_index: [Int]?
    public let duration: Double?
    public let start: Double?
    public let is_final: Bool?
    public let speech_final: Bool?
    public let channel: Channel?
    
    public struct Channel: Codable {
        public let alternatives: [Alternative]?
        
        public struct Alternative: Codable {
            public let transcript: String?
            public let confidence: Double?
            public let words: [Word]?
            
            public struct Word: Codable {
                public let word: String?
                public let start: Double?
                public let end: Double?
                public let confidence: Double?
            }
        }
    }
}

// MARK: - Connection Diagnostics

public struct ConnectionDiagnostics: Codable {
    public let state: DeepgramClient.ConnectionState
    public let attempts: Int
    public let retryAttempt: Int
    public let totalMessages: Int
    public let totalErrors: Int
    public let latency: TimeInterval
    public let uptime: TimeInterval?
    
    public var errorRate: Double {
        guard totalMessages > 0 else { return 0.0 }
        return Double(totalErrors) / Double(totalMessages)
    }
    
    public var isHealthy: Bool {
        return state == .connected && errorRate < 0.1 && latency < 2.0
    }
}