import Foundation

/// Export format enumeration
public enum ExportFormat: String, CaseIterable, Identifiable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case srt = "srt"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .srt: return "SRT"
        }
    }

    public var fileExtension: String {
        return rawValue
    }
}

/// Simple export configuration
public struct ExportConfiguration {
    public let includeTimestamps: Bool
    public let includeMetadata: Bool

    public init(includeTimestamps: Bool = true, includeMetadata: Bool = true) {
        self.includeTimestamps = includeTimestamps
        self.includeMetadata = includeMetadata
    }
}

/// Export result
public struct ExportResult {
    public let success: Bool
    public let filePath: URL?
    public let error: (any Error)?
    public let metadata: [String: Any]

    public init(success: Bool, filePath: URL? = nil, error: (any Error)? = nil, metadata: [String: Any] = [:]) {
        self.success = success
        self.filePath = filePath
        self.error = error
        self.metadata = metadata
    }
}
