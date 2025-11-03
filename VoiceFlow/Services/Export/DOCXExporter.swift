import Foundation

/// Production-ready DOCX exporter using Office Open XML format
/// Generates Microsoft Word-compatible .docx files programmatically
public final class DOCXExporter {

    // MARK: - Types

    /// DOCX formatting options
    public struct FormattingOptions: Sendable {
        public let fontName: String
        public let fontSize: Int
        public let lineSpacing: Double
        public let headerEnabled: Bool
        public let footerEnabled: Bool
        public let boldTitle: Bool
        public let italicMetadata: Bool

        public init(
            fontName: String = "Calibri",
            fontSize: Int = 11,
            lineSpacing: Double = 1.15,
            headerEnabled: Bool = true,
            footerEnabled: Bool = true,
            boldTitle: Bool = true,
            italicMetadata: Bool = false
        ) {
            self.fontName = fontName
            self.fontSize = fontSize
            self.lineSpacing = lineSpacing
            self.headerEnabled = headerEnabled
            self.footerEnabled = footerEnabled
            self.boldTitle = boldTitle
            self.italicMetadata = italicMetadata
        }

        public static let `default` = FormattingOptions()
    }

    public enum DOCXError: Error, CustomStringConvertible {
        case invalidSession
        case fileCreationFailed
        case archiveCreationFailed
        case xmlGenerationFailed

        public var description: String {
            switch self {
            case .invalidSession: return "Invalid transcription session"
            case .fileCreationFailed: return "Failed to create DOCX file"
            case .archiveCreationFailed: return "Failed to create DOCX archive"
            case .xmlGenerationFailed: return "Failed to generate XML content"
            }
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Interface

    /// Export transcription session to DOCX format
    /// - Parameters:
    ///   - session: Transcription session to export
    ///   - url: Destination file URL
    ///   - configuration: Export configuration
    ///   - options: DOCX formatting options
    /// - Throws: DOCXError if export fails
    public func export(
        session: TranscriptionSession,
        to url: URL,
        configuration: ExportConfiguration,
        options: FormattingOptions = .default
    ) throws {
        // Validate session
        guard !session.transcription.isEmpty else {
            throw DOCXError.invalidSession
        }

        // Create temporary directory for DOCX structure
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Generate DOCX structure
        try createDOCXStructure(
            at: tempDir,
            session: session,
            configuration: configuration,
            options: options
        )

        // Create ZIP archive (DOCX is a ZIP file)
        try createArchive(from: tempDir, to: url)
    }

    // MARK: - DOCX Structure Creation

    internal func createDOCXStructure(
        at directory: URL,
        session: TranscriptionSession,
        configuration: ExportConfiguration,
        options: FormattingOptions
    ) throws {
        // Create directory structure
        let docDir = directory.appendingPathComponent("word")
        let relsDir = directory.appendingPathComponent("_rels")
        let wordRelsDir = docDir.appendingPathComponent("_rels")

        try fileManager.createDirectory(at: docDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)

        // Generate required files
        try generateContentTypes(at: directory)
        try generateRels(at: relsDir)
        try generateDocumentRels(at: wordRelsDir, options: options)
        try generateDocument(at: docDir, session: session, configuration: configuration, options: options)

        if options.headerEnabled {
            try generateHeader(at: docDir, session: session)
        }

        if options.footerEnabled {
            try generateFooter(at: docDir, session: session)
        }
    }

    // MARK: - Archive Creation

    internal func createArchive(from directory: URL, to destination: URL) throws {
        // Use system zip command for reliable DOCX creation
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destination.path, "."]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DOCXError.archiveCreationFailed
        }
    }

    // MARK: - Helpers

    internal func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    internal func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    internal func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
