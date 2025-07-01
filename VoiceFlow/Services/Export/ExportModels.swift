import Foundation
import CoreGraphics

// MARK: - Export Models and Protocols

// Note: TranscriptionSession is imported from TranscriptionModels.swift

/// Represents a transcription segment with timing information
public struct TranscriptionSegment: Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    
    public var duration: TimeInterval {
        endTime - startTime
    }
    
    public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

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
public struct ExportResult: Sendable {
    public let success: Bool
    public let outputURL: URL?
    public let error: ExportError?
    public let fileSize: Int?
    public let exportDuration: TimeInterval
    
    public init(
        success: Bool,
        outputURL: URL? = nil,
        error: ExportError? = nil,
        fileSize: Int? = nil,
        exportDuration: TimeInterval
    ) {
        self.success = success
        self.outputURL = outputURL
        self.error = error
        self.fileSize = fileSize
        self.exportDuration = exportDuration
    }
}

/// Errors that can occur during export
public enum ExportError: Error, LocalizedError, Sendable {
    case invalidFormat
    case fileWriteError(String)
    case templateError(String)
    case unsupportedConfiguration
    case insufficientData
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The export format is not supported."
        case .fileWriteError(let details):
            return "Failed to write file: \(details)"
        case .templateError(let details):
            return "Template processing error: \(details)"
        case .unsupportedConfiguration:
            return "The export configuration is not supported for this format."
        case .insufficientData:
            return "Insufficient data to generate export."
        case .permissionDenied:
            return "Permission denied to write to the specified location."
        }
    }
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
    func exportDidProgress(_ progress: ExportProgress)
    func exportDidComplete(_ result: ExportResult)
    func exportDidFail(_ error: ExportError)
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