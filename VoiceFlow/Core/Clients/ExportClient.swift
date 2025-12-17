import Dependencies
import DependenciesMacros
import Foundation

// MARK: - ExportOptions

/// Options for exporting transcriptions.
/// Note: This complements ExportConfiguration from ExportModels.swift
public struct ExportOptions: Sendable, Equatable {
    public let includeTimestamps: Bool
    public let includeSpeakerLabels: Bool
    public let includeConfidence: Bool
    public let title: String?
    public let author: String?

    public init(
        includeTimestamps: Bool = false,
        includeSpeakerLabels: Bool = false,
        includeConfidence: Bool = false,
        title: String? = nil,
        author: String? = nil
    ) {
        self.includeTimestamps = includeTimestamps
        self.includeSpeakerLabels = includeSpeakerLabels
        self.includeConfidence = includeConfidence
        self.title = title
        self.author = author
    }

    public static let `default` = ExportOptions()
}

// MARK: - ExportError

public enum ExportError: LocalizedError, Sendable {
    case emptyContent
    case invalidFormat
    case writeFailed(any Error)
    case unsupportedFormat(ExportFormat)

    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Cannot export empty content"
        case .invalidFormat:
            return "Invalid export format"
        case .writeFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .unsupportedFormat(let format):
            return "\(format.displayName) export is not supported"
        }
    }
}

// MARK: - ExportClient

/// Client for exporting transcriptions to various formats.
/// Note: Uses ExportFormat and ExportResult from ExportModels.swift
@DependencyClient
public struct ExportClient: Sendable {
    /// Export text to a file.
    /// - Parameters:
    ///   - text: The text to export.
    ///   - format: The export format.
    ///   - url: The destination URL.
    ///   - options: Export options.
    /// - Returns: The export result.
    public var export: @Sendable (
        _ text: String,
        _ format: ExportFormat,
        _ url: URL,
        _ options: ExportOptions
    ) async throws -> ExportResult

    /// Export transcript segments with timing information.
    /// - Parameters:
    ///   - segments: The transcript segments.
    ///   - format: The export format.
    ///   - url: The destination URL.
    ///   - options: Export options.
    /// - Returns: The export result.
    public var exportSegments: @Sendable (
        _ segments: [TranscriptSegment],
        _ format: ExportFormat,
        _ url: URL,
        _ options: ExportOptions
    ) async throws -> ExportResult

    /// Get available export formats.
    public var availableFormats: @Sendable () -> [ExportFormat] = {
        ExportFormat.allCases
    }

    /// Generate a suggested filename.
    public var suggestedFilename: @Sendable (_ format: ExportFormat) -> String = { format in
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return "transcript-\(timestamp).\(format.fileExtension)"
    }
}

// MARK: - DependencyKey

extension ExportClient: DependencyKey {
    public static var testValue: ExportClient {
        ExportClient()
    }

    public static var previewValue: ExportClient {
        ExportClient()
    }
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var exportClient: ExportClient {
        get { self[ExportClient.self] }
        set { self[ExportClient.self] = newValue }
    }
}
