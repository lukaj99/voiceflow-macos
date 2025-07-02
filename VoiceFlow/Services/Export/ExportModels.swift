import Foundation
import CoreGraphics

// MARK: - Export Models and Protocols

// Note: TranscriptionSession and TranscriptionSegment are imported from TranscriptionModels.swift

/// Metadata associated with a transcription session
public struct SessionMetadata: Sendable {
    public let title: String?
    public let speaker: String?
    public let location: String?
    public let tags: [String]
    
    public init(
        title: String? = nil,
        speaker: String? = nil,
        location: String? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.speaker = speaker
        self.location = location
        self.tags = tags
    }
}

/// Supported languages for transcription
public enum Language: String, CaseIterable, Sendable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case hindi = "hi"
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }
}

/// Available export formats
public enum ExportFormat: String, CaseIterable, Sendable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case srt = "srt"
    
    public var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .docx: return "Word Document"
        case .srt: return "SRT Subtitles"
        }
    }
    
    public var fileExtension: String {
        return rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .text: return "text/plain"
        case .markdown: return "text/markdown"
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .srt: return "application/x-subrip"
        }
    }
}

/// Configuration options for export
public struct ExportConfiguration: Sendable {
    public let includeTimestamps: Bool
    public let includeConfidenceScores: Bool
    public let includeMetadata: Bool
    public let customHeader: String?
    public let customFooter: String?
    public let pageLayout: PageLayout?
    
    public enum PageLayout: Sendable {
        case portrait
        case landscape
    }
    
    public init(
        includeTimestamps: Bool = false,
        includeConfidenceScores: Bool = false,
        includeMetadata: Bool = true,
        customHeader: String? = nil,
        customFooter: String? = nil,
        pageLayout: PageLayout? = nil
    ) {
        self.includeTimestamps = includeTimestamps
        self.includeConfidenceScores = includeConfidenceScores
        self.includeMetadata = includeMetadata
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.pageLayout = pageLayout
    }
    
    public static let `default` = ExportConfiguration()
}

/// Result of an export operation
public enum ExportResult: Sendable {
    case data(Data)
    case fileURL(URL)
    case error(ExportError)
    
    public var success: Bool {
        switch self {
        case .data, .fileURL:
            return true
        case .error:
            return false
        }
    }
    
    public var outputURL: URL? {
        switch self {
        case .fileURL(let url):
            return url
        default:
            return nil
        }
    }
    
    public var error: ExportError? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }
    
    public var fileSize: Int? {
        switch self {
        case .data(let data):
            return data.count
        default:
            return nil
        }
    }
    
    public var exportDuration: TimeInterval {
        return 0 // Simplified for now
    }
}

/// Errors that can occur during export
public enum ExportError: Error, LocalizedError, Sendable {
    case invalidFormat
    case fileWriteError(URL, Error)
    case templateError(String)
    case unsupportedConfiguration
    case insufficientData
    case permissionDenied
    case cancelled
    case encodingError(Error)
    case invalidSession
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The export format is not supported."
        case .fileWriteError(let url, let error):
            return "Failed to write file to \(url.path): \(error.localizedDescription)"
        case .templateError(let details):
            return "Template processing error: \(details)"
        case .unsupportedConfiguration:
            return "The export configuration is not supported for this format."
        case .insufficientData:
            return "Insufficient data to generate export."
        case .permissionDenied:
            return "Permission denied to write to the specified location."
        case .cancelled:
            return "Export operation was cancelled."
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .invalidSession:
            return "Invalid transcription session."
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}

/// Base protocol for exporters used by ExportManager
public protocol Exporter: Sendable {
    associatedtype Configuration
    
    func export(
        session: TranscriptionSession,
        configuration: Configuration,
        progressDelegate: ExportProgressDelegate?
    ) async throws -> ExportResult
    
    func exportToFile(
        session: TranscriptionSession,
        configuration: Configuration,
        outputURL: URL,
        progressDelegate: ExportProgressDelegate?
    ) async throws -> ExportResult
    
    func cancel()
}

/// Protocol for export handlers
public protocol ExportHandler: Sendable {
    var supportedFormat: ExportFormat { get }
    
    func export(
        session: TranscriptionSession,
        configuration: ExportConfiguration
    ) async throws -> Data
    
    func validateConfiguration(_ configuration: ExportConfiguration) -> Bool
}

/// Export progress tracking
public struct ExportProgress: Sendable {
    public let stage: Stage
    public let percentage: Double
    public let currentItem: String?
    
    public enum Stage: String, Sendable {
        case preparing = "Preparing"
        case processing = "Processing"
        case formatting = "Formatting"
        case writing = "Writing"
        case complete = "Complete"
    }
    
    public init(stage: Stage, percentage: Double, currentItem: String? = nil) {
        self.stage = stage
        self.percentage = percentage
        self.currentItem = currentItem
    }
}

/// Protocol for tracking export progress
public protocol ExportProgressDelegate: Sendable {
    func exportDidStart(for format: ExportFormat)
    func exportDidStart()
    func exportDidProgress(_ progress: ExportProgress)
    func exportDidComplete(_ result: ExportResult)
    func exportDidComplete(result: ExportResult)
    func exportDidFail(_ error: ExportError)
    func exportDidUpdateProgress(_ progress: Double, currentStep: String)
}

/// PDF-specific export configuration
public struct PDFExportConfiguration: Sendable {
    public let includeHeader: Bool
    public let includeFooter: Bool
    public let includePageNumbers: Bool
    public let fontSize: Double
    public let fontName: String
    public let pageSize: PageSize
    public let margins: Margins
    
    public enum PageSize: String, CaseIterable, Sendable {
        case letter = "Letter"
        case a4 = "A4"
        case legal = "Legal"
        
        public var size: CGSize {
            switch self {
            case .letter: return CGSize(width: 612, height: 792)
            case .a4: return CGSize(width: 595, height: 842)
            case .legal: return CGSize(width: 612, height: 1008)
            }
        }
    }
    
    public struct Margins: Sendable {
        public let top: Double
        public let bottom: Double
        public let left: Double
        public let right: Double
        
        public init(top: Double = 72, bottom: Double = 72, left: Double = 72, right: Double = 72) {
            self.top = top
            self.bottom = bottom
            self.left = left
            self.right = right
        }
    }
    
    public init(
        includeHeader: Bool = true,
        includeFooter: Bool = true,
        includePageNumbers: Bool = true,
        fontSize: Double = 12,
        fontName: String = "Helvetica",
        pageSize: PageSize = .letter,
        margins: Margins = Margins()
    ) {
        self.includeHeader = includeHeader
        self.includeFooter = includeFooter
        self.includePageNumbers = includePageNumbers
        self.fontSize = fontSize
        self.fontName = fontName
        self.pageSize = pageSize
        self.margins = margins
    }
    
    public static let `default` = PDFExportConfiguration()
}

/// Text-specific export configuration
public struct TextExportConfiguration: Sendable {
    public let includeMetadata: Bool
    public let customHeader: String?
    public let customFooter: String?
    public let lineEnding: LineEnding
    
    public enum LineEnding: String, CaseIterable, Sendable {
        case unix = "\n"
        case windows = "\r\n"
        case mac = "\r"
    }
    
    public init(
        includeMetadata: Bool = true,
        customHeader: String? = nil,
        customFooter: String? = nil,
        lineEnding: LineEnding = .unix
    ) {
        self.includeMetadata = includeMetadata
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.lineEnding = lineEnding
    }
    
    public static let `default` = TextExportConfiguration()
}

/// Markdown-specific export configuration
public struct MarkdownExportConfiguration: Sendable {
    public let includeMetadata: Bool
    public let includeTOC: Bool
    public let customHeader: String?
    public let customFooter: String?
    public let enableSyntaxHighlighting: Bool
    
    public init(
        includeMetadata: Bool = true,
        includeTOC: Bool = false,
        customHeader: String? = nil,
        customFooter: String? = nil,
        enableSyntaxHighlighting: Bool = true
    ) {
        self.includeMetadata = includeMetadata
        self.includeTOC = includeTOC
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.enableSyntaxHighlighting = enableSyntaxHighlighting
    }
    
    public static let `default` = MarkdownExportConfiguration()
}

/// DOCX-specific export configuration
public struct DocxExportConfiguration: Sendable {
    public let includeMetadata: Bool
    public let fontSize: Double
    public let fontName: String
    public let includeHeader: Bool
    public let includeFooter: Bool
    public let customHeader: String?
    public let customFooter: String?
    
    public init(
        includeMetadata: Bool = true,
        fontSize: Double = 12,
        fontName: String = "Calibri",
        includeHeader: Bool = true,
        includeFooter: Bool = true,
        customHeader: String? = nil,
        customFooter: String? = nil
    ) {
        self.includeMetadata = includeMetadata
        self.fontSize = fontSize
        self.fontName = fontName
        self.includeHeader = includeHeader
        self.includeFooter = includeFooter
        self.customHeader = customHeader
        self.customFooter = customFooter
    }
    
    public static let `default` = DocxExportConfiguration()
}

/// SRT-specific export configuration
public struct SRTExportConfiguration: Sendable {
    public let maxCharsPerLine: Int
    public let maxLinesPerSubtitle: Int
    public let minSubtitleDuration: TimeInterval
    public let maxSubtitleDuration: TimeInterval
    
    public init(
        maxCharsPerLine: Int = 50,
        maxLinesPerSubtitle: Int = 2,
        minSubtitleDuration: TimeInterval = 1.0,
        maxSubtitleDuration: TimeInterval = 7.0
    ) {
        self.maxCharsPerLine = maxCharsPerLine
        self.maxLinesPerSubtitle = maxLinesPerSubtitle
        self.minSubtitleDuration = minSubtitleDuration
        self.maxSubtitleDuration = maxSubtitleDuration
    }
    
    public static let `default` = SRTExportConfiguration()
}