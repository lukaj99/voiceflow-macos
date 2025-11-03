import Foundation

/// Supported export file formats for transcriptions
///
/// Defines all supported export formats with associated display names and file extensions.
/// Each format provides specific formatting and structure appropriate for its use case.
///
/// # Available Formats
/// - `.text`: Plain text format with basic formatting
/// - `.markdown`: Markdown format with rich formatting and structure
/// - `.pdf`: PDF document format for professional presentation
/// - `.docx`: Microsoft Word document format for editing
/// - `.srt`: SubRip subtitle format for video captions
///
/// # Example
/// ```swift
/// let format: ExportFormat = .markdown
/// print(format.displayName)      // "Markdown"
/// print(format.fileExtension)    // "md"
/// ```
///
/// - SeeAlso: `ExportManager`, `ExportConfiguration`
public enum ExportFormat: String, CaseIterable, Identifiable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case srt = "srt"

    /// Unique identifier for the format (uses raw value)
    public var id: String { rawValue }

    /// Human-readable display name for UI presentation
    ///
    /// Returns a user-friendly name suitable for display in menus, buttons, and file pickers.
    ///
    /// # Example
    /// ```swift
    /// ExportFormat.markdown.displayName  // "Markdown"
    /// ExportFormat.text.displayName      // "Text"
    /// ```
    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .srt: return "SRT"
        }
    }

    /// File extension for the format (without leading dot)
    ///
    /// Returns the standard file extension for this format, suitable for use in file names.
    ///
    /// # Example
    /// ```swift
    /// let fileName = "transcript.\(ExportFormat.markdown.fileExtension)"  // "transcript.md"
    /// ```
    public var fileExtension: String {
        return rawValue
    }
}

/// Configuration options for transcription export
///
/// Controls various aspects of the export process including metadata inclusion,
/// timestamp formatting, and other format-specific options.
///
/// # Example
/// ```swift
/// let config = ExportConfiguration(
///     includeTimestamps: true,
///     includeMetadata: true
/// )
/// ```
///
/// - SeeAlso: `ExportManager.exportTranscription(session:format:to:configuration:)`
public struct ExportConfiguration {
    /// Whether to include timestamp information in the export
    ///
    /// When enabled, timestamp data will be included in applicable formats (e.g., SRT subtitles).
    public let includeTimestamps: Bool

    /// Whether to include session metadata in the export
    ///
    /// When enabled, includes information such as date, duration, word count, and confidence.
    public let includeMetadata: Bool

    /// Initialize export configuration with optional settings
    ///
    /// - Parameters:
    ///   - includeTimestamps: Whether to include timestamps (default: true)
    ///   - includeMetadata: Whether to include metadata header (default: true)
    public init(includeTimestamps: Bool = true, includeMetadata: Bool = true) {
        self.includeTimestamps = includeTimestamps
        self.includeMetadata = includeMetadata
    }
}

/// Result of an export operation
///
/// Encapsulates the outcome of an export operation including success status,
/// file path, error information, and export metadata.
///
/// # Example
/// ```swift
/// let result = try exportManager.exportTranscription(session: session, format: .text, to: url)
/// if result.success {
///     print("Exported to: \(result.filePath?.path ?? "unknown")")
///     print("File size: \(result.metadata["size"] ?? 0) characters")
/// } else if let error = result.error {
///     print("Export failed: \(error)")
/// }
/// ```
///
/// - SeeAlso: `ExportManager.exportTranscription(session:format:to:configuration:)`
public struct ExportResult {
    /// Whether the export operation succeeded
    public let success: Bool

    /// The file URL where content was exported (if successful)
    public let filePath: URL?

    /// Error information if the export failed
    public let error: (any Error)?

    /// Additional metadata about the export (format, size, timestamp, etc.)
    public let metadata: [String: Any]

    /// Initialize an export result
    ///
    /// - Parameters:
    ///   - success: Whether the operation succeeded
    ///   - filePath: The output file URL (if successful)
    ///   - error: Error information (if failed)
    ///   - metadata: Additional export metadata
    public init(success: Bool, filePath: URL? = nil, error: (any Error)? = nil, metadata: [String: Any] = [:]) {
        self.success = success
        self.filePath = filePath
        self.error = error
        self.metadata = metadata
    }
}
