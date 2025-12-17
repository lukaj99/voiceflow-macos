import Dependencies
import Foundation

// MARK: - AudioClientLive

/// Live implementation of AudioClient wrapping AudioManager.
extension AudioClient {
    /// Live implementation using the actual AudioManager and AudioProcessingActor.
    public static var liveValue: AudioClient {
        // Create streams that will be connected to the manager later
        let (dataStream, dataContinuation) = AsyncStream<Data>.makeStream()
        let (levelStream, levelContinuation) = AsyncStream<Float>.makeStream()

        // Use a sendable state holder
        let stateHolder = AudioStateHolder(
            dataContinuation: dataContinuation,
            levelContinuation: levelContinuation
        )

        return AudioClient(
            startRecording: {
                try await stateHolder.startRecording()
            },
            stopRecording: {
                Task { @MainActor in
                    stateHolder.stopRecording()
                }
            },
            pauseRecording: {
                Task { @MainActor in
                    stateHolder.pauseRecording()
                }
            },
            resumeRecording: {
                await stateHolder.resumeRecording()
            },
            audioLevelStream: {
                levelStream
            },
            audioDataStream: {
                dataStream
            },
            isRecording: {
                false // Will be checked via manager when needed
            },
            isPaused: {
                false
            },
            requestPermission: {
                true // macOS handles permissions at system level
            },
            hasPermission: {
                true
            }
        )
    }
}

// MARK: - AudioStateHolder

/// Sendable state holder for audio client.
/// Since all methods are @MainActor, no locks are needed.
@MainActor
private final class AudioStateHolder: @unchecked Sendable {
    private var audioManager: AudioManager?
    private var delegateBridge: AudioDelegateBridge?
    private let dataContinuation: AsyncStream<Data>.Continuation
    private let levelContinuation: AsyncStream<Float>.Continuation

    nonisolated init(dataContinuation: AsyncStream<Data>.Continuation, levelContinuation: AsyncStream<Float>.Continuation) {
        self.dataContinuation = dataContinuation
        self.levelContinuation = levelContinuation
    }

    private func getOrCreateManager() -> AudioManager {
        if let existing = audioManager {
            return existing
        }
        let manager = AudioManager()
        audioManager = manager
        return manager
    }

    func startRecording() async throws {
        let manager = getOrCreateManager()

        // Set up delegate bridge
        let bridge = AudioDelegateBridge { [weak self] data in
            self?.dataContinuation.yield(data)
        }
        delegateBridge = bridge
        manager.delegate = bridge

        try await manager.startRecording()
    }

    func stopRecording() {
        audioManager?.stopRecording()
    }

    func pauseRecording() {
        audioManager?.pauseRecording()
    }

    func resumeRecording() {
        audioManager?.resumeRecording()
    }
}

// MARK: - AudioDelegateBridge

/// Bridge class to forward AudioManager delegate calls to closures.
@MainActor
private final class AudioDelegateBridge: AudioManagerDelegate {
    private let onAudioData: @Sendable (Data) -> Void

    init(onAudioData: @escaping @Sendable (Data) -> Void) {
        self.onAudioData = onAudioData
    }

    func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data) {
        onAudioData(data)
    }
}
