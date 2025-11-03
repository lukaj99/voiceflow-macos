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

    private func createDOCXStructure(
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

    // MARK: - XML Generation

    private func generateContentTypes(at directory: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
            <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
        </Types>
        """

        let url = directory.appendingPathComponent("[Content_Types].xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateRels(at directory: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        let url = directory.appendingPathComponent(".rels")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateDocumentRels(at directory: URL, options: FormattingOptions) throws {
        var relationships = ""
        var rId = 1

        if options.headerEnabled {
            relationships += """
                <Relationship Id="rId\(rId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>

            """
            rId += 1
        }

        if options.footerEnabled {
            relationships += """
                <Relationship Id="rId\(rId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>

            """
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(relationships)</Relationships>
        """

        let url = directory.appendingPathComponent("document.xml.rels")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateDocument(
        at directory: URL,
        session: TranscriptionSession,
        configuration: ExportConfiguration,
        options: FormattingOptions
    ) throws {
        var paragraphs = ""

        // Title
        paragraphs += generateParagraph(
            text: "VoiceFlow Transcription",
            bold: options.boldTitle,
            fontSize: options.fontSize + 4
        )

        // Metadata section
        if configuration.includeMetadata {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            paragraphs += generateParagraph(
                text: "Date: \(dateFormatter.string(from: session.startTime))",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Duration: \(formatDuration(session.duration))",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Words: \(session.wordCount)",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Confidence: \(Int(session.averageConfidence * 100))%",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            // Separator
            paragraphs += generateParagraph(text: "")
        }

        // Transcription content
        let lines = session.transcription.components(separatedBy: .newlines)
        for line in lines {
            paragraphs += generateParagraph(
                text: line.isEmpty ? " " : xmlEscape(line),
                fontSize: options.fontSize
            )
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
        \(paragraphs)
            </w:body>
        </w:document>
        """

        let url = directory.appendingPathComponent("document.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateHeader(at directory: URL, session: TranscriptionSession) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:jc w:val="right"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="20"/>
                        <w:color w:val="808080"/>
                    </w:rPr>
                    <w:t>VoiceFlow - \(formatDate(session.startTime))</w:t>
                </w:r>
            </w:p>
        </w:hdr>
        """

        let url = directory.appendingPathComponent("header1.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateFooter(at directory: URL, session: TranscriptionSession) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="20"/>
                        <w:color w:val="808080"/>
                    </w:rPr>
                    <w:t>Session ID: \(session.id.uuidString)</w:t>
                </w:r>
            </w:p>
        </w:ftr>
        """

        let url = directory.appendingPathComponent("footer1.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func generateParagraph(
        text: String,
        bold: Bool = false,
        italic: Bool = false,
        fontSize: Int = 11
    ) -> String {
        var runProperties = ""

        if bold {
            runProperties += "<w:b/>"
        }
        if italic {
            runProperties += "<w:i/>"
        }
        runProperties += "<w:sz w:val=\"\(fontSize * 2)\"/>"

        return """
                <w:p>
                    <w:r>
                        <w:rPr>
        \(runProperties)
                        </w:rPr>
                        <w:t>\(text)</w:t>
                    </w:r>
                </w:p>

        """
    }

    // MARK: - Archive Creation

    private func createArchive(from directory: URL, to destination: URL) throws {
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
