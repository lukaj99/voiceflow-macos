import Foundation

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

// MARK: - Connection State

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
    public let state: ConnectionState
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

// MARK: - Delegate Protocol

public protocol DeepgramClientDelegate: AnyObject {
    func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool)
}
