import Foundation

/// Manages transcription export to various file formats
///
/// `ExportManager` provides a unified interface for exporting transcription sessions
/// to multiple file formats including plain text, Markdown, PDF, DOCX, and SRT subtitle files.
/// The manager handles all format conversions, metadata embedding, and file I/O operations.
///
/// # Supported Formats
/// - **Text (.txt)**: Plain text with optional metadata header
/// - **Markdown (.md)**: Formatted Markdown with metadata and section headers
/// - **PDF (.pdf)**: Professional PDF documents (simplified implementation)
/// - **DOCX (.docx)**: Microsoft Word documents (simplified implementation)
/// - **SRT (.srt)**: Subtitle files for video (simplified implementation)
///
/// # Example Usage
/// ```swift
/// let exportManager = ExportManager()
/// let session = TranscriptionSession(
///     transcription: "Hello world",
///     startTime: Date(),
///     duration: 10.0,
///     wordCount: 2,
///     averageConfidence: 0.95
/// )
///
/// do {
///     let result = try exportManager.exportTranscription(
///         session: session,
///         format: .markdown,
///         to: URL(fileURLWithPath: "/path/to/export.md"),
///         configuration: ExportConfiguration(includeMetadata: true)
///     )
///     print("Export successful: \(result.filePath)")
/// } catch {
///     print("Export failed: \(error)")
/// }
/// ```
///
/// # Performance
/// - Export operations are synchronous and complete in milliseconds for typical transcriptions
/// - Memory usage scales linearly with transcription length
/// - All file operations use atomic writes to prevent data corruption
///
/// - Note: This is a simplified implementation following 2025 best practices.
///   PDF export uses PDFKit for production-ready rendering.
///   DOCX export uses Office Open XML format for Microsoft Word compatibility.
///   Advanced format features (SRT timing) may require enhancement for production use.
///
/// - SeeAlso: `ExportFormat`, `ExportConfiguration`, `ExportResult`
public final class ExportManager {

    private let pdfExporter: PDFExporter
    private let docxExporter: DOCXExporter

    /// Initialize a new export manager
    ///
    /// Creates a new instance ready to perform export operations across all supported formats.
    public init() {
        self.pdfExporter = PDFExporter()
        self.docxExporter = DOCXExporter()
    }

    /// Export a transcription session to a file in the specified format
    ///
    /// Converts the transcription session to the requested format and writes it to the specified URL.
    /// The export operation includes optional metadata and timestamps based on the configuration.
    ///
    /// - Parameters:
    ///   - session: The transcription session containing the text and metadata to export
    ///   - format: The target file format (text, markdown, pdf, docx, or srt)
    ///   - url: The file URL where the exported content will be written
    ///   - configuration: Optional export configuration controlling metadata and timestamps
    /// - Returns: An `ExportResult` containing the success status, file path, and metadata
    /// - Throws: File I/O errors if the export location is not writable or disk is full
    ///
    /// # Example
    /// ```swift
    /// let result = try exportTranscription(
    ///     session: mySession,
    ///     format: .markdown,
    ///     to: fileURL,
    ///     configuration: ExportConfiguration(includeMetadata: true)
    /// )
    /// ```
    ///
    /// - Note: Writes are atomic to prevent corruption on failure
    public func exportTranscription(
        session: TranscriptionSession,
        format: ExportFormat,
        to url: URL,
        configuration: ExportConfiguration = ExportConfiguration()
    ) throws -> ExportResult {

        // Handle PDF format separately with PDFExporter
        if format == .pdf {
            let pdfConfig = PDFExporter.PDFConfiguration(
                includeTimestamps: configuration.includeTimestamps,
                includeMetadata: configuration.includeMetadata
            )

            try pdfExporter.exportToPDF(session: session, to: url, configuration: pdfConfig)

            return ExportResult(
                success: true,
                filePath: url,
                metadata: [
                    "format": format.rawValue,
                    "timestamp": Date()
                ]
            )
        }

        // Handle DOCX format separately with DOCXExporter
        if format == .docx {
            try docxExporter.export(session: session, to: url, configuration: configuration)

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0

            return ExportResult(
                success: true,
                filePath: url,
                metadata: [
                    "format": format.rawValue,
                    "size": fileSize,
                    "timestamp": Date()
                ]
            )
        }

        // Handle text-based formats
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

    /// Generate content in the specified format
    ///
    /// Internal method that converts a transcription session to the appropriate format string.
    /// Delegates to format-specific generation methods based on the requested format.
    ///
    /// - Parameters:
    ///   - session: The transcription session to convert
    ///   - format: The target export format
    ///   - configuration: Export configuration options
    /// - Returns: Formatted content string ready for file output
    private func generateContent(session: TranscriptionSession, format: ExportFormat, configuration: ExportConfiguration) -> String {
        switch format {
        case .text:
            return generateTextContent(session: session, configuration: configuration)
        case .markdown:
            return generateMarkdownContent(session: session, configuration: configuration)
        case .pdf:
            // PDF handled separately in exportTranscription method
            return ""
        case .docx:
            // DOCX handled separately in exportTranscription method
            return ""
        case .srt:
            // Simplified - just return text content for now
            return generateTextContent(session: session, configuration: configuration)
        }
    }

    /// Generate plain text content with optional metadata header
    ///
    /// Creates a plain text representation of the transcription with an optional metadata header
    /// containing session information (date, duration, word count, confidence).
    ///
    /// - Parameters:
    ///   - session: The transcription session to format
    ///   - configuration: Configuration controlling metadata inclusion
    /// - Returns: Plain text formatted content string
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

    /// Generate Markdown formatted content with metadata
    ///
    /// Creates a Markdown representation with proper formatting, section headers,
    /// and an optional metadata section in Markdown format.
    ///
    /// - Parameters:
    ///   - session: The transcription session to format
    ///   - configuration: Configuration controlling metadata inclusion
    /// - Returns: Markdown formatted content string
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

    /// Format duration as a human-readable string
    ///
    /// Converts a time interval into an abbreviated, localized string representation
    /// showing hours, minutes, and seconds (e.g., "1h 23m 45s").
    ///
    /// - Parameter duration: The time interval in seconds to format
    /// - Returns: Formatted duration string (e.g., "1h 23m 45s" or "0s")
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
