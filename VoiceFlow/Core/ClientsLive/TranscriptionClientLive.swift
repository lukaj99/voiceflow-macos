import Dependencies
import Foundation

// MARK: - TranscriptionClientLive

/// Live implementation of TranscriptionClient wrapping DeepgramClient.
extension TranscriptionClient {
    /// Live implementation using the actual DeepgramClient.
    public static var liveValue: TranscriptionClient {
        // Create stream that will be connected to the client later
        let (transcriptStream, transcriptContinuation) = AsyncStream<TranscriptSegment>.makeStream()

        // Use a sendable state holder
        let stateHolder = TranscriptionStateHolder(transcriptContinuation: transcriptContinuation)

        return TranscriptionClient(
            connect: { apiKey in
                try await stateHolder.connect(apiKey: apiKey)
            },
            disconnect: {
                await stateHolder.disconnect()
            },
            sendAudio: { data in
                await stateHolder.sendAudio(data)
            },
            transcriptStream: {
                transcriptStream
            },
            isConnected: {
                false // Checked via state
            },
            connectionState: {
                .disconnected // Checked via state
            }
        )
    }
}

// MARK: - TranscriptionConnectionError

/// Errors that can occur during transcription connection.
public enum TranscriptionConnectionError: Error, LocalizedError {
    case connectionFailed
    case authenticationFailed
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to transcription service"
        case .authenticationFailed:
            return "Authentication failed - check API key"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
}

// MARK: - TranscriptionStateHolder

/// Sendable state holder for transcription client.
/// Since all methods are @MainActor, no locks are needed.
@MainActor
private final class TranscriptionStateHolder: @unchecked Sendable {
    private var deepgramClient: DeepgramClient?
    private var delegateBridge: TranscriptDelegateBridge?
    private let transcriptContinuation: AsyncStream<TranscriptSegment>.Continuation

    nonisolated init(transcriptContinuation: AsyncStream<TranscriptSegment>.Continuation) {
        self.transcriptContinuation = transcriptContinuation
    }

    private func getOrCreateClient() -> DeepgramClient {
        if let existing = deepgramClient {
            return existing
        }
        let client = DeepgramClient()
        deepgramClient = client
        return client
    }

    func connect(apiKey: String) async throws {
        let client = getOrCreateClient()
        let continuation = transcriptContinuation

        // Set up delegate bridge - yield directly to continuation
        let bridge = TranscriptDelegateBridge { text, isFinal in
            let segment = TranscriptSegment(
                text: text,
                timestamp: Date(),
                isFinal: isFinal,
                confidence: 1.0,
                words: nil
            )
            continuation.yield(segment)
        }
        delegateBridge = bridge
        client.delegate = bridge
        client.connect(apiKey: apiKey, autoReconnect: true)

        // Wait for connection with timeout
        let timeout: UInt64 = 5_000_000_000 // 5 seconds
        let start = DispatchTime.now()

        while true {
            if client.isConnected {
                return
            }

            let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            if elapsed > timeout {
                throw TranscriptionConnectionError.connectionFailed
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    func disconnect() {
        deepgramClient?.disconnect()
    }

    func sendAudio(_ data: Data) {
        deepgramClient?.sendAudioData(data)
    }
}

// MARK: - TranscriptDelegateBridge

/// Bridge class to forward DeepgramClient delegate calls to closures.
@MainActor
private final class TranscriptDelegateBridge: DeepgramClientDelegate {
    private let onTranscript: @Sendable (String, Bool) -> Void

    init(onTranscript: @escaping @Sendable (String, Bool) -> Void) {
        self.onTranscript = onTranscript
    }

    func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool) {
        onTranscript(transcript, isFinal)
    }
}
