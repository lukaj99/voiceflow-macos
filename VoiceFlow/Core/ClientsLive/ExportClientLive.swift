import Dependencies
import Foundation

// MARK: - ExportClientLive

/// Live implementation of ExportClient wrapping ExportManager.
extension ExportClient {
    /// Live implementation using the actual ExportManager.
    public static var liveValue: ExportClient {
        // Use a sendable state holder
        let stateHolder = ExportStateHolder()

        return ExportClient(
            export: { text, format, url, options in
                try stateHolder.exportText(
                    text: text,
                    format: format,
                    url: url,
                    options: options
                )
            },
            exportSegments: { segments, format, url, options in
                try stateHolder.exportSegments(
                    segments: segments,
                    format: format,
                    url: url,
                    options: options
                )
            },
            availableFormats: {
                ExportFormat.allCases
            },
            suggestedFilename: { format in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                return "transcript-\(timestamp).\(format.fileExtension)"
            }
        )
    }
}

// MARK: - ExportStateHolder

/// Sendable state holder for export operations.
private final class ExportStateHolder: @unchecked Sendable {
    private let exportManager = ExportManager()
    private let lock = NSLock()

    func exportText(
        text: String,
        format: ExportFormat,
        url: URL,
        options: ExportOptions
    ) throws -> ExportResult {
        lock.lock()
        defer { lock.unlock() }

        let session = createSession(
            from: text,
            segments: [],
            options: options
        )

        let config = ExportConfiguration(
            includeTimestamps: options.includeTimestamps,
            includeMetadata: true
        )

        return try exportManager.exportTranscription(
            session: session,
            format: format,
            to: url,
            configuration: config
        )
    }

    func exportSegments(
        segments: [TranscriptSegment],
        format: ExportFormat,
        url: URL,
        options: ExportOptions
    ) throws -> ExportResult {
        lock.lock()
        defer { lock.unlock() }

        let transcriptionSegments = segments.map { segment in
            TranscriptionSegment(
                text: segment.text,
                startTime: segment.timestamp.timeIntervalSinceReferenceDate,
                endTime: segment.timestamp.timeIntervalSinceReferenceDate,
                confidence: Float(segment.confidence)
            )
        }

        let fullText = segments.map(\.text).joined(separator: " ")

        let session = createSession(
            from: fullText,
            segments: transcriptionSegments,
            options: options,
            startTime: segments.first?.timestamp,
            endTime: segments.last?.timestamp
        )

        let config = ExportConfiguration(
            includeTimestamps: options.includeTimestamps,
            includeMetadata: true
        )

        return try exportManager.exportTranscription(
            session: session,
            format: format,
            to: url,
            configuration: config
        )
    }

    private func createSession(
        from text: String,
        segments: [TranscriptionSegment],
        options: ExportOptions,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) -> TranscriptionSession {
        let now = Date()
        let actualStartTime = startTime ?? now
        let actualEndTime = endTime ?? now

        let metadata = TranscriptionSession.Metadata(
            appName: "VoiceFlow",
            privacyMode: .balanced,
            title: options.title,
            tags: []
        )

        return TranscriptionSession(
            id: UUID(),
            startTime: actualStartTime,
            endTime: actualEndTime,
            duration: actualEndTime.timeIntervalSince(actualStartTime),
            wordCount: text.split(separator: " ").count,
            averageConfidence: segments.isEmpty ? 1.0 : Double(segments.reduce(0) { $0 + $1.confidence }) / Double(segments.count),
            context: "",
            transcription: text,
            segments: segments,
            metadata: metadata,
            createdAt: now,
            language: .english
        )
    }
}
