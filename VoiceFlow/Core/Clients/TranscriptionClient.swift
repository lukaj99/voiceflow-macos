import Dependencies
import DependenciesMacros
import Foundation

// MARK: - TranscriptSegment

/// A segment of transcribed text with metadata.
public struct TranscriptSegment: Sendable, Equatable, Codable {
    public let text: String
    public let timestamp: Date
    public let isFinal: Bool
    public let confidence: Double
    public let words: [TranscriptWord]?

    public init(
        text: String,
        timestamp: Date = Date(),
        isFinal: Bool = false,
        confidence: Double = 1.0,
        words: [TranscriptWord]? = nil
    ) {
        self.text = text
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.confidence = confidence
        self.words = words
    }
}

/// A single word with timing information.
public struct TranscriptWord: Sendable, Equatable, Codable {
    public let word: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let confidence: Double

    public init(word: String, start: TimeInterval, end: TimeInterval, confidence: Double) {
        self.word = word
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

// MARK: - TranscriptionClient

/// Client for real-time transcription services (Deepgram, etc.).
/// Note: Uses ConnectionState from DeepgramModels.swift
@DependencyClient
public struct TranscriptionClient: Sendable {
    /// Connect to the transcription service.
    /// - Parameter apiKey: The API key for authentication.
    public var connect: @Sendable (_ apiKey: String) async throws -> Void

    /// Disconnect from the transcription service.
    public var disconnect: @Sendable () async -> Void

    /// Send audio data to be transcribed.
    /// - Parameter data: Raw audio data (PCM 16-bit, 16kHz, mono).
    public var sendAudio: @Sendable (_ data: Data) async -> Void

    /// Stream of transcription results.
    public var transcriptStream: @Sendable () -> AsyncStream<TranscriptSegment> = {
        AsyncStream { _ in }
    }

    /// Whether currently connected to the service.
    public var isConnected: @Sendable () -> Bool = { false }

    /// Current connection state.
    public var connectionState: @Sendable () -> ConnectionState = { .disconnected }
}

// MARK: - DependencyKey

extension TranscriptionClient: DependencyKey {
    public static var testValue: TranscriptionClient {
        TranscriptionClient()
    }

    public static var previewValue: TranscriptionClient {
        TranscriptionClient()
    }
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var transcriptionClient: TranscriptionClient {
        get { self[TranscriptionClient.self] }
        set { self[TranscriptionClient.self] = newValue }
    }
}
