import Foundation

/// Handles parsing and processing of Deepgram WebSocket messages
@MainActor
public class DeepgramResponseParser {

    // MARK: - Properties

    private weak var delegate: (any DeepgramClientDelegate)?
    private weak var client: DeepgramClient?

    public var totalErrors = 0
    public var networkLatency: TimeInterval = 0

    // MARK: - Initialization

    public init(delegate: (any DeepgramClientDelegate)?, client: DeepgramClient?) {
        self.delegate = delegate
        self.client = client
    }

    // MARK: - Public Methods

    /// Update the delegate reference
    public func updateDelegate(_ delegate: (any DeepgramClientDelegate)?) {
        self.delegate = delegate
    }

    /// Parse and handle incoming text message from WebSocket
    public func handleTextMessage(_ text: String, currentRetryAttempt: Int) -> Int {
        var updatedRetryAttempt = currentRetryAttempt

        print("📥 Received message: \(text)")

        guard let data = text.data(using: .utf8) else {
            print("❌ Failed to convert message to data")
            totalErrors += 1
            return updatedRetryAttempt
        }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

            // Reset retry attempts on successful message
            if updatedRetryAttempt > 0 {
                print("✅ Connection recovered after \(updatedRetryAttempt) attempts")
                updatedRetryAttempt = 0
            }

            // Extract transcript if available
            if let channel = response.channel,
               let alternative = channel.alternatives?.first,
               let transcript = alternative.transcript,
               !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                let isFinal = response.is_final ?? false
                let confidence = alternative.confidence ?? 0.0

                let status = isFinal ? "final" : "interim"
                let confidenceStr = String(format: "%.2f", confidence)
                print("📝 Transcript (\(status), confidence: \(confidenceStr)): \(transcript)")

                // Calculate latency if we have timing info
                if let start = response.start {
                    networkLatency = Date().timeIntervalSince1970 - start
                }

                Task { @MainActor in
                    guard let client = client else { return }
                    delegate?.deepgramClient(client, didReceiveTranscript: transcript, isFinal: isFinal)
                }
            }

        } catch {
            print("❌ Failed to decode Deepgram response: \(error)")
            totalErrors += 1
        }

        return updatedRetryAttempt
    }
}
