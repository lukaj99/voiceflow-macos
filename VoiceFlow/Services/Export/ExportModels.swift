import Foundation

// MARK: - Export Models and Protocols

/// Represents a transcription session with all necessary data for export
public struct TranscriptionSession {
    public let id: UUID
    public let text: String
    public let metadata: SessionMetadata
    public let segments: [TranscriptionSegment]
    public let language: Language
    public let createdAt: Date
    public let updatedAt: Date
    
    /// Computed property for total word count
    public var wordCount: Int {
        text.split(separator: " ").count
    }
    
    /// Computed property for total duration
    public var duration: TimeInterval {
        guard let lastSegment = segments.last else { return 0 }
        return lastSegment.endTime
    }
    
    public init(
        id: UUID,
        text: String,
        metadata: SessionMetadata,
        segments: [TranscriptionSegment],
        language: Language,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.text = text
        self.metadata = metadata
        self.segments = segments
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Metadata associated with a transcription session
public struct SessionMetadata {
    public let title: String?
    public let speaker: String?
    public let location: String?
    public let tags: [String]
    public let customFields: [String: Any]
    
    public init(title: String? = nil,
         speaker: String? = nil,
         location: String? = nil,
         tags: [String] = [],
         customFields: [String: Any] = [:]) {
        self.title = title
        self.speaker = speaker
        self.location = location
        self.tags = tags
        self.customFields = customFields
    }
}

/// Represents a single segment of transcribed text with timing information
public struct TranscriptionSegment {
    public let id: UUID
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    public let words: [WordTiming]
    
    /// Duration of this segment
    public var duration: TimeInterval {
        endTime - startTime
    }
    
    public init(
        id: UUID,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double,
        words: [WordTiming]
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.words = words
    }
}

/// Word-level timing information
public struct WordTiming {
    public let word: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    
    public init(
        word: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double
    ) {
        self.word = word
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

/// Language information
public struct Language {
    public let code: String // e.g., "en-US"
    public let name: String // e.g., "English (United States)"
    
    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
    
    public static let english = Language(code: "en-US", name: "English (United States)")
}

// MARK: - Export Configuration

/// Base protocol for export configuration
public protocol ExportConfiguration {
    var includeMetadata: Bool { get }
    var includeTimestamps: Bool { get }
    var includeConfidenceScores: Bool { get }
}

/// Text export configuration
public struct TextExportConfiguration: ExportConfiguration {
    public let includeMetadata: Bool
    public let includeTimestamps: Bool
    public let includeConfidenceScores: Bool
    public let lineBreaksBetweenSegments: Bool
    
    public init(includeMetadata: Bool = true,
                includeTimestamps: Bool = false,
                includeConfidenceScores: Bool = false,
                lineBreaksBetweenSegments: Bool = true) {
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.includeConfidenceScores = includeConfidenceScores
        self.lineBreaksBetweenSegments = lineBreaksBetweenSegments
    }
}

/// Markdown export configuration
public struct MarkdownExportConfiguration: ExportConfiguration {
    public let includeMetadata: Bool
    public let includeTimestamps: Bool
    public let includeConfidenceScores: Bool
    public let includeTableOfContents: Bool
    public let segmentHeaderLevel: Int
    
    public init(includeMetadata: Bool = true,
                includeTimestamps: Bool = true,
                includeConfidenceScores: Bool = false,
                includeTableOfContents: Bool = true,
                segmentHeaderLevel: Int = 2) {
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.includeConfidenceScores = includeConfidenceScores
        self.includeTableOfContents = includeTableOfContents
        self.segmentHeaderLevel = segmentHeaderLevel
    }
}

/// DOCX export configuration
public struct DocxExportConfiguration: ExportConfiguration {
    public let includeMetadata: Bool
    public let includeTimestamps: Bool
    public let includeConfidenceScores: Bool
    public let fontSize: Double
    public let fontName: String
    public let includePageNumbers: Bool
    
    public init(includeMetadata: Bool = true,
                includeTimestamps: Bool = false,
                includeConfidenceScores: Bool = false,
                fontSize: Double = 12.0,
                fontName: String = "Helvetica",
                includePageNumbers: Bool = true) {
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.includeConfidenceScores = includeConfidenceScores
        self.fontSize = fontSize
        self.fontName = fontName
        self.includePageNumbers = includePageNumbers
    }
}

/// PDF export configuration
public struct PDFExportConfiguration: ExportConfiguration {
    public let includeMetadata: Bool
    public let includeTimestamps: Bool
    public let includeConfidenceScores: Bool
    public let pageSize: PageSize
    public let margins: PDFMargins
    public let fontSize: CGFloat
    public let fontName: String
    public let includePageNumbers: Bool
    public let includeHeader: Bool
    
    public enum PageSize {
        case a4
        case letter
        case legal
        
        var size: CGSize {
            switch self {
            case .a4:
                return CGSize(width: 595.28, height: 841.89)
            case .letter:
                return CGSize(width: 612, height: 792)
            case .legal:
                return CGSize(width: 612, height: 1008)
            }
        }
    }
    
    public struct PDFMargins {
        let top: CGFloat
        let bottom: CGFloat
        let left: CGFloat
        let right: CGFloat
        
        public init(top: CGFloat = 72, bottom: CGFloat = 72, left: CGFloat = 72, right: CGFloat = 72) {
            self.top = top
            self.bottom = bottom
            self.left = left
            self.right = right
        }
    }
    
    public init(includeMetadata: Bool = true,
                includeTimestamps: Bool = false,
                includeConfidenceScores: Bool = false,
                pageSize: PageSize = .letter,
                margins: PDFMargins = PDFMargins(),
                fontSize: CGFloat = 12.0,
                fontName: String = "Helvetica",
                includePageNumbers: Bool = true,
                includeHeader: Bool = true) {
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.includeConfidenceScores = includeConfidenceScores
        self.pageSize = pageSize
        self.margins = margins
        self.fontSize = fontSize
        self.fontName = fontName
        self.includePageNumbers = includePageNumbers
        self.includeHeader = includeHeader
    }
}

/// SRT export configuration
public struct SRTExportConfiguration: ExportConfiguration {
    public let includeMetadata: Bool = false // SRT doesn't support metadata
    public let includeTimestamps: Bool = true // Always true for SRT
    public let includeConfidenceScores: Bool = false // SRT doesn't support confidence
    public let maxCharactersPerLine: Int
    public let maxLinesPerSubtitle: Int
    public let minimumDuration: TimeInterval
    
    public init(maxCharactersPerLine: Int = 42,
                maxLinesPerSubtitle: Int = 2,
                minimumDuration: TimeInterval = 1.0) {
        self.maxCharactersPerLine = maxCharactersPerLine
        self.maxLinesPerSubtitle = maxLinesPerSubtitle
        self.minimumDuration = minimumDuration
    }
}

// MARK: - Export Result

/// Result of an export operation
public enum ExportResult {
    case data(Data)
    case fileURL(URL)
    case error(ExportError)
}

// MARK: - Export Errors

/// Errors that can occur during export
public enum ExportError: LocalizedError {
    case invalidSession
    case fileWriteError(URL, Error)
    case encodingError(Error)
    case unsupportedFormat
    case configurationError(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Invalid transcription session"
        case .fileWriteError(let url, let error):
            return "Failed to write file to \(url.path): \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .unsupportedFormat:
            return "Unsupported export format"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .cancelled:
            return "Export operation was cancelled"
        }
    }
}

// MARK: - Progress Reporting

/// Protocol for reporting export progress
public protocol ExportProgressDelegate: AnyObject {
    func exportDidStart()
    func exportDidUpdateProgress(_ progress: Double, currentStep: String)
    func exportDidComplete(result: ExportResult)
    func exportDidFail(error: ExportError)
}

/// Default implementation for optional methods
public extension ExportProgressDelegate {
    func exportDidStart() {}
    func exportDidUpdateProgress(_ progress: Double, currentStep: String) {}
}

// MARK: - Exporter Protocol

/// Base protocol for all exporters
public protocol Exporter {
    associatedtype Configuration: ExportConfiguration
    
    /// Export a transcription session with the given configuration
    func export(session: TranscriptionSession,
                configuration: Configuration,
                progressDelegate: ExportProgressDelegate?) async throws -> ExportResult
    
    /// Export to a specific file URL
    func exportToFile(session: TranscriptionSession,
                      configuration: Configuration,
                      fileURL: URL,
                      progressDelegate: ExportProgressDelegate?) async throws
    
    /// Cancel ongoing export operation
    func cancelExport()
}

// MARK: - Helper Extensions

extension TimeInterval {
    /// Format time interval as HH:MM:SS,mmm for SRT format
    var srtTimeFormat: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        let milliseconds = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    /// Format time interval as human-readable string
    var humanReadable: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}