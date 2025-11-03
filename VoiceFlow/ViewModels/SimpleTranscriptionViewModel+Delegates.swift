import Foundation

// MARK: - AudioManagerDelegate

extension SimpleTranscriptionViewModel: AudioManagerDelegate {

    nonisolated public func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data) {
        Task { @MainActor in
            // Send audio data to Deepgram
            deepgramClient.sendAudioData(data)
        }
    }
}

// MARK: - DeepgramClientDelegate

extension SimpleTranscriptionViewModel: DeepgramClientDelegate {

    nonisolated public func deepgramClient(
        _ client: DeepgramClient,
        didReceiveTranscript transcript: String,
        isFinal: Bool
    ) {
        Task { @MainActor in
            if isFinal {
                await handleFinalTranscript(transcript)
            } else {
                handleInterimTranscript(transcript)
            }
        }
    }

    func handleFinalTranscript(_ transcript: String) async {
        // Remove any existing interim result before adding final
        removeInterimResult()

        // Check for medical terminology and auto-switch model if needed
        autoSwitchModelIfNeeded(for: transcript)

        // Handle global text input if enabled
        if globalInputEnabled {
            await handleGlobalTextInsertion(transcript)
        } else {
            appendToLocalTranscript(transcript)
            print("📝 Added final transcript: \(transcript)")
        }
    }

    func removeInterimResult() {
        let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty, lines.last?.hasPrefix("[Interim]") == true else { return }

        let previousLines = lines.dropLast().joined(separator: "\n")
        transcriptionText = previousLines
    }

    func handleGlobalTextInsertion(_ transcript: String) async {
        let textToInsert = hasInsertedGlobalText ? " \(transcript)" : transcript
        let result = await globalTextInputService.insertText(textToInsert)

        switch result {
        case .success:
            hasInsertedGlobalText = true
            print("📝 Final transcript inserted globally: \(transcript)")
            appendToLocalTranscript("[Global] \(transcript)")
        case .accessibilityDenied:
            errorMessage = "Global input failed: Accessibility permissions required"
            appendToLocalTranscript(transcript)
        case .noActiveTextField:
            print("⚠️ No active text field found - displaying locally")
            appendToLocalTranscript(transcript)
        case .insertionFailed(let error):
            errorMessage = "Global input failed: \(error.localizedDescription)"
            appendToLocalTranscript(transcript)
        }
    }

    func appendToLocalTranscript(_ text: String) {
        if !transcriptionText.isEmpty {
            transcriptionText += " "
        }
        transcriptionText += text
    }

    func handleInterimTranscript(_ transcript: String) {
        let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
        if !lines.isEmpty && lines.last?.hasPrefix("[Interim]") == true {
            // Replace last interim line
            let previousLines = lines.dropLast().joined(separator: "\n")
            transcriptionText = previousLines + (previousLines.isEmpty ? "" : "\n") + "[Interim] \(transcript)"
        } else {
            // Add new interim line
            transcriptionText += (transcriptionText.isEmpty ? "" : "\n") + "[Interim] \(transcript)"
        }
        print("💭 Showing interim transcript: \(transcript)")
    }
}
