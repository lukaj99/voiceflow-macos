import Foundation

/// Protocol defining the interface for export management
@MainActor
public protocol ExportManagerProtocol: AnyObject, Sendable {
    
    // MARK: - Export Methods
    
    func exportSession(
        _ session: StoredTranscriptionSession,
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> Data
    
    func exportSessions(
        _ sessions: [StoredTranscriptionSession],
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> Data
    
    // MARK: - File Export
    
    func exportSessionToFile(
        _ session: StoredTranscriptionSession,
        format: ExportFormat,
        fileURL: URL,
        options: ExportOptions
    ) async throws
    
    // MARK: - Supported Formats
    
    func supportedFormats() -> [ExportFormat]
    func defaultOptions(for format: ExportFormat) -> ExportOptions
}

// MARK: - Export Types

public enum ExportFormat: String, CaseIterable, Sendable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case srt = "srt"
    case json = "json"
    case csv = "csv"
    
    public var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .docx: return "Word Document"
        case .srt: return "SubRip Subtitle"
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }
    
    public var fileExtension: String {
        return rawValue
    }
}

public struct ExportOptions: Sendable {
    public let includeTimestamps: Bool
    public let includeMetadata: Bool
    public let includeConfidence: Bool
    public let includeSpeakerLabels: Bool
    public let includeWordTimings: Bool
    public let dateFormat: String
    public let customHeader: String?
    public let customFooter: String?
    
    public init(
        includeTimestamps: Bool = true,
        includeMetadata: Bool = true,
        includeConfidence: Bool = false,
        includeSpeakerLabels: Bool = false,
        includeWordTimings: Bool = false,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss",
        customHeader: String? = nil,
        customFooter: String? = nil
    ) {
        self.includeTimestamps = includeTimestamps
        self.includeMetadata = includeMetadata
        self.includeConfidence = includeConfidence
        self.includeSpeakerLabels = includeSpeakerLabels
        self.includeWordTimings = includeWordTimings
        self.dateFormat = dateFormat
        self.customHeader = customHeader
        self.customFooter = customFooter
    }
    
    public static var `default`: ExportOptions {
        ExportOptions()
    }
    
    public static var minimal: ExportOptions {
        ExportOptions(
            includeTimestamps: false,
            includeMetadata: false,
            includeConfidence: false,
            includeSpeakerLabels: false,
            includeWordTimings: false
        )
    }
    
    public static var detailed: ExportOptions {
        ExportOptions(
            includeTimestamps: true,
            includeMetadata: true,
            includeConfidence: true,
            includeSpeakerLabels: true,
            includeWordTimings: true
        )
    }
}