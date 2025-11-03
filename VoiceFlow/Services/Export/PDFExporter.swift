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

    /// Create document metadata attributes
    private func createDocumentAttributes(session: TranscriptionSession) -> [PDFDocumentAttribute: Any] {
        var attributes: [PDFDocumentAttribute: Any] = [:]

        attributes[.titleAttribute] = session.metadata.title ?? "VoiceFlow Transcription"
        attributes[.authorAttribute] = "VoiceFlow"
        attributes[.creatorAttribute] = "VoiceFlow"
        attributes[.producerAttribute] = "VoiceFlow PDF Exporter"
        attributes[.creationDateAttribute] = session.startTime
        attributes[.modificationDateAttribute] = Date()
        attributes[.subjectAttribute] = "Voice Transcription"

        return attributes
    }

    /// Create content string with metadata
    private func createContent(
        session: TranscriptionSession,
        configuration: PDFConfiguration
    ) -> String {
        var content = ""

        if configuration.includeMetadata {
            content += "VoiceFlow Transcription\n\n"

            if let title = session.metadata.title {
                content += "Title: \(title)\n"
            }

            content += "Date: \(formatDate(session.startTime))\n"
            content += "Duration: \(formatDuration(session.duration))\n"
            content += "Words: \(session.wordCount)\n"
            content += "Confidence: \(formatPercentage(session.averageConfidence))\n"
            content += "Language: \(session.language.displayName)\n"

            if !session.metadata.tags.isEmpty {
                content += "Tags: \(session.metadata.tags.joined(separator: ", "))\n"
            }

            content += "\n---\n\n"
        }

        // Add transcription with optional timestamps
        if configuration.includeTimestamps && !session.segments.isEmpty {
            for segment in session.segments {
                let timestamp = formatTimestamp(segment.startTime)
                content += "[\(timestamp)] \(segment.text)\n\n"
            }
        } else {
            content += session.transcription
        }

        return content
    }

    /// Create PDF pages with paginated content
    private func createPages(
        content: String,
        font: NSFont,
        configuration: PDFConfiguration,
        session: TranscriptionSession
    ) throws -> [PDFPage] {
        var pages: [PDFPage] = []

        // Calculate content area
        let contentRect = CGRect(
            x: configuration.margins.left,
            y: configuration.margins.bottom,
            width: configuration.pageSize.width - configuration.margins.left - configuration.margins.right,
            height: configuration.pageSize.height - configuration.margins.top - configuration.margins.bottom
        )

        // Create attributed string with line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = configuration.lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: content, attributes: attributes)

        // Paginate content
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        var currentRange = CFRange(location: 0, length: 0)
        var currentIndex = 0
        var pageNumber = 1

        while currentIndex < attributedString.length {
            // Create page
            let page = PDFPage()
            let pageRect = CGRect(origin: .zero, size: configuration.pageSize)

            // Create graphics context
            guard let context = CGContext(
                data: nil,
                width: Int(pageRect.width),
                height: Int(pageRect.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw PDFExportError.pageCreationFailed
            }

            // Draw header
            if configuration.includeHeader {
                let headerText = configuration.headerText ?? "VoiceFlow Transcription"
                drawHeader(context: context, text: headerText, rect: pageRect, configuration: configuration)
            }

            // Draw content
            let path = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)

            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1.0, y: -1.0)
            CTFrameDraw(frame, context)
            context.restoreGState()

            // Draw footer
            if configuration.includeFooter {
                let footerText = configuration.footerText ?? "Page \(pageNumber)"
                drawFooter(context: context, text: footerText, rect: pageRect, configuration: configuration)
            }

            // Create image from context
            guard let image = context.makeImage() else {
                throw PDFExportError.pageCreationFailed
            }

            // Create PDF page from image
            let pdfPage = PDFPage(image: NSImage(cgImage: image, size: pageRect.size))
            guard let validPage = pdfPage else {
                throw PDFExportError.pageCreationFailed
            }

            pages.append(validPage)

            // Calculate next range
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentIndex = visibleRange.location + visibleRange.length
            currentRange = CFRange(location: currentIndex, length: 0)
            pageNumber += 1

            // Safety check to prevent infinite loop
            if visibleRange.length == 0 {
                break
            }
        }

        return pages
    }

    /// Draw header on page
    private func drawHeader(
        context: CGContext,
        text: String,
        rect: CGRect,
        configuration: PDFConfiguration
    ) {
        let headerRect = CGRect(
            x: configuration.margins.left,
            y: rect.height - configuration.margins.top + 20,
            width: rect.width - configuration.margins.left - configuration.margins.right,
            height: 30
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(in: headerRect)
    }

    /// Draw footer on page
    private func drawFooter(
        context: CGContext,
        text: String,
        rect: CGRect,
        configuration: PDFConfiguration
    ) {
        let footerRect = CGRect(
            x: configuration.margins.left,
            y: 20,
            width: rect.width - configuration.margins.left - configuration.margins.right,
            height: 30
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(in: footerRect)
    }

    // MARK: - Formatting Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value * 100)
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
