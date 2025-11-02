import Foundation

/// Simple working export manager following 2025 best practices
public final class ExportManager {

    public init() {}

    /// Export transcription to file
    public func exportTranscription(
        session: TranscriptionSession,
        format: ExportFormat,
        to url: URL,
        configuration: ExportConfiguration = ExportConfiguration()
    ) throws -> ExportResult {

        let content = generateContent(session: session, format: format, configuration: configuration)

        try content.write(to: url, atomically: true, encoding: .utf8)

        return ExportResult(
            success: true,
            filePath: url,
            metadata: [
                "format": format.rawValue,
                "size": content.count,
                "timestamp": Date()
            ]
        )
    }

    /// Generate content for export
    private func generateContent(session: TranscriptionSession, format: ExportFormat, configuration: ExportConfiguration) -> String {
        switch format {
        case .text:
            return generateTextContent(session: session, configuration: configuration)
        case .markdown:
            return generateMarkdownContent(session: session, configuration: configuration)
        case .pdf, .docx, .srt:
            // Simplified - just return text content for now
            return generateTextContent(session: session, configuration: configuration)
        }
    }

    /// Generate plain text content
    private func generateTextContent(session: TranscriptionSession, configuration: ExportConfiguration) -> String {
        var content = ""

        if configuration.includeMetadata {
            content += "VoiceFlow Transcription\n"
            content += "Date: \(session.startTime.formatted())\n"
            content += "Duration: \(formatDuration(session.duration))\n"
            content += "Words: \(session.wordCount)\n"
            content += "Confidence: \(Int(session.averageConfidence * 100))%\n"
            content += "\n---\n\n"
        }

        content += session.transcription

        return content
    }

    /// Generate markdown content
    private func generateMarkdownContent(session: TranscriptionSession, configuration: ExportConfiguration) -> String {
        var content = "# VoiceFlow Transcription\n\n"

        if configuration.includeMetadata {
            content += "**Date**: \(session.startTime.formatted())\n"
            content += "**Duration**: \(formatDuration(session.duration))\n"
            content += "**Words**: \(session.wordCount)\n"
            content += "**Confidence**: \(Int(session.averageConfidence * 100))%\n\n"
            content += "---\n\n"
        }

        content += "## Transcript\n\n"
        content += session.transcription

        return content
    }

    /// Format duration as readable string
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
