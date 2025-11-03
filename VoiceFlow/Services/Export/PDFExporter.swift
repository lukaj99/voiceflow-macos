import Foundation
import PDFKit
import AppKit

/// Production-ready PDF exporter using PDFKit framework
/// Supports customizable formatting, pagination, and metadata
public final class PDFExporter {

    // MARK: - Configuration

    /// PDF formatting options
    public struct PDFConfiguration {
        public let fontSize: CGFloat
        public let fontName: String
        public let lineSpacing: CGFloat
        public let margins: PDFMargins
        public let pageSize: CGSize
        public let includeTimestamps: Bool
        public let includeMetadata: Bool
        public let includeHeader: Bool
        public let includeFooter: Bool
        public let headerText: String?
        public let footerText: String?

        public init(
            fontSize: CGFloat = 12.0,
            fontName: String = "Helvetica",
            lineSpacing: CGFloat = 1.5,
            margins: PDFMargins = PDFMargins(),
            pageSize: CGSize = CGSize(width: 612, height: 792), // US Letter
            includeTimestamps: Bool = true,
            includeMetadata: Bool = true,
            includeHeader: Bool = true,
            includeFooter: Bool = true,
            headerText: String? = nil,
            footerText: String? = nil
        ) {
            self.fontSize = fontSize
            self.fontName = fontName
            self.lineSpacing = lineSpacing
            self.margins = margins
            self.pageSize = pageSize
            self.includeTimestamps = includeTimestamps
            self.includeMetadata = includeMetadata
            self.includeHeader = includeHeader
            self.includeFooter = includeFooter
            self.headerText = headerText
            self.footerText = footerText
        }

        public static var `default`: PDFConfiguration {
            PDFConfiguration()
        }
    }

    /// PDF page margins
    public struct PDFMargins {
        public let top: CGFloat
        public let bottom: CGFloat
        public let left: CGFloat
        public let right: CGFloat

        public init(top: CGFloat = 72, bottom: CGFloat = 72, left: CGFloat = 72, right: CGFloat = 72) {
            self.top = top
            self.bottom = bottom
            self.left = left
            self.right = right
        }
    }

    // MARK: - Errors

    public enum PDFExportError: LocalizedError {
        case invalidConfiguration
        case emptyContent
        case fontNotFound
        case pageCreationFailed
        case fileWriteFailed(URL)
        case documentCreationFailed

        public var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Invalid PDF configuration"
            case .emptyContent:
                return "Cannot create PDF with empty content"
            case .fontNotFound:
                return "Specified font not found"
            case .pageCreationFailed:
                return "Failed to create PDF page"
            case .fileWriteFailed(let url):
                return "Failed to write PDF to file: \(url.path)"
            case .documentCreationFailed:
                return "Failed to create PDF document"
            }
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Export transcription session to PDF
    /// - Parameters:
    ///   - session: Transcription session to export
    ///   - url: File URL to write PDF to
    ///   - configuration: PDF formatting configuration
    /// - Throws: PDFExportError if export fails
    public func exportToPDF(
        session: TranscriptionSession,
        to url: URL,
        configuration: PDFConfiguration = .default
    ) throws {
        // Validate configuration
        guard configuration.fontSize > 0,
              configuration.pageSize.width > 0,
              configuration.pageSize.height > 0 else {
            throw PDFExportError.invalidConfiguration
        }

        // Check content
        guard !session.transcription.isEmpty else {
            throw PDFExportError.emptyContent
        }

        // Create PDF document
        let pdfDocument = try createPDFDocument(session: session, configuration: configuration)

        // Write to file
        guard pdfDocument.write(to: url) else {
            throw PDFExportError.fileWriteFailed(url)
        }
    }

    /// Create PDF data from transcription session
    /// - Parameters:
    ///   - session: Transcription session to export
    ///   - configuration: PDF formatting configuration
    /// - Returns: PDF data
    /// - Throws: PDFExportError if creation fails
    public func createPDFData(
        session: TranscriptionSession,
        configuration: PDFConfiguration = .default
    ) throws -> Data {
        let pdfDocument = try createPDFDocument(session: session, configuration: configuration)

        guard let data = pdfDocument.dataRepresentation() else {
            throw PDFExportError.documentCreationFailed
        }

        return data
    }

    // MARK: - Private Methods

    /// Create PDF document from session
    private func createPDFDocument(
        session: TranscriptionSession,
        configuration: PDFConfiguration
    ) throws -> PDFDocument {
        // Validate font
        guard let font = NSFont(name: configuration.fontName, size: configuration.fontSize) else {
            throw PDFExportError.fontNotFound
        }

        // Create document
        let pdfDocument = PDFDocument()

        // Set document attributes (metadata)
        if configuration.includeMetadata {
            let attributes = createDocumentAttributes(session: session)
            pdfDocument.documentAttributes = attributes
        }

        // Create content string
        let content = createContent(session: session, configuration: configuration)

        // Create pages with content
        let pages = try createPages(
            content: content,
            font: font,
            configuration: configuration,
            session: session
        )

        // Add pages to document
        for (index, page) in pages.enumerated() {
            pdfDocument.insert(page, at: index)
        }

        guard pdfDocument.pageCount > 0 else {
            throw PDFExportError.pageCreationFailed
        }

        return pdfDocument
    }

}
