import Foundation
import PDFKit
import AppKit

// MARK: - PDF Generation Extension

extension PDFExporter {

    struct PageResult {
        let pdfPage: PDFPage
        let nextIndex: Int
        let visibleLength: Int
    }

    /// Create document metadata attributes
    func createDocumentAttributes(session: TranscriptionSession) -> [PDFDocumentAttribute: Any] {
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
    func createContent(
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
    func createPages(
        content: String,
        font: NSFont,
        configuration: PDFConfiguration,
        session: TranscriptionSession
    ) throws -> [PDFPage] {
        let contentRect = calculateContentRect(for: configuration)
        let attributedString = createAttributedString(
            content: content,
            font: font,
            configuration: configuration
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        return try paginateContent(
            attributedString: attributedString,
            framesetter: framesetter,
            contentRect: contentRect,
            configuration: configuration
        )
    }

    func calculateContentRect(for configuration: PDFConfiguration) -> CGRect {
        return CGRect(
            x: configuration.margins.left,
            y: configuration.margins.bottom,
            width: configuration.pageSize.width - configuration.margins.left - configuration.margins.right,
            height: configuration.pageSize.height - configuration.margins.top - configuration.margins.bottom
        )
    }

    func createAttributedString(
        content: String,
        font: NSFont,
        configuration: PDFConfiguration
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = configuration.lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: content, attributes: attributes)
    }

    func paginateContent(
        attributedString: NSAttributedString,
        framesetter: CTFramesetter,
        contentRect: CGRect,
        configuration: PDFConfiguration
    ) throws -> [PDFPage] {
        var pages: [PDFPage] = []
        var currentRange = CFRange(location: 0, length: 0)
        var currentIndex = 0
        var pageNumber = 1

        while currentIndex < attributedString.length {
            let page = try createSinglePage(
                framesetter: framesetter,
                currentRange: currentRange,
                contentRect: contentRect,
                configuration: configuration,
                pageNumber: pageNumber
            )

            pages.append(page.pdfPage)

            // Calculate next range
            currentIndex = page.nextIndex
            currentRange = CFRange(location: currentIndex, length: 0)
            pageNumber += 1

            // Safety check to prevent infinite loop
            if page.visibleLength == 0 {
                break
            }
        }

        return pages
    }

    func createSinglePage(
        framesetter: CTFramesetter,
        currentRange: CFRange,
        contentRect: CGRect,
        configuration: PDFConfiguration,
        pageNumber: Int
    ) throws -> PageResult {
        let pageRect = CGRect(origin: .zero, size: configuration.pageSize)

        guard let context = createGraphicsContext(pageRect: pageRect) else {
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

        // Create PDF page from context
        guard let image = context.makeImage(),
              let pdfPage = PDFPage(image: NSImage(cgImage: image, size: pageRect.size)) else {
            throw PDFExportError.pageCreationFailed
        }

        let visibleRange = CTFrameGetVisibleStringRange(frame)
        let nextIndex = visibleRange.location + visibleRange.length

        return PageResult(pdfPage: pdfPage, nextIndex: nextIndex, visibleLength: visibleRange.length)
    }

    func createGraphicsContext(pageRect: CGRect) -> CGContext? {
        return CGContext(
            data: nil,
            width: Int(pageRect.width),
            height: Int(pageRect.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Draw header on page
    func drawHeader(
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
    func drawFooter(
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

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value * 100)
    }

    func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
