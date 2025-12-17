import Dependencies
import DependenciesMacros
import Foundation

// MARK: - AudioClient

/// Client for audio capture and processing operations.
/// Uses swift-dependencies for testable dependency injection.
@DependencyClient
public struct AudioClient: Sendable {
    /// Start recording audio from the microphone.
    public var startRecording: @Sendable () async throws -> Void

    /// Stop recording audio.
    public var stopRecording: @Sendable () -> Void

    /// Pause recording without disconnecting.
    public var pauseRecording: @Sendable () -> Void

    /// Resume recording after pause.
    public var resumeRecording: @Sendable () async throws -> Void

    /// Stream of audio level values (0.0 to 1.0).
    public var audioLevelStream: @Sendable () -> AsyncStream<Float> = {
        AsyncStream { _ in }
    }

    /// Stream of raw audio data for transcription.
    public var audioDataStream: @Sendable () -> AsyncStream<Data> = {
        AsyncStream { _ in }
    }

    /// Whether recording is currently active.
    public var isRecording: @Sendable () -> Bool = { false }

    /// Whether recording is paused.
    public var isPaused: @Sendable () -> Bool = { false }

    /// Request microphone permission.
    public var requestPermission: @Sendable () async -> Bool = { false }

    /// Check if microphone permission is granted.
    public var hasPermission: @Sendable () -> Bool = { false }
}

// MARK: - DependencyKey

extension AudioClient: DependencyKey {
    /// Test implementation with no-op defaults
    public static var testValue: AudioClient {
        AudioClient()
    }

    /// Preview implementation for SwiftUI previews
    public static var previewValue: AudioClient {
        AudioClient()
    }
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var audioClient: AudioClient {
        get { self[AudioClient.self] }
        set { self[AudioClient.self] = newValue }
    }
}
