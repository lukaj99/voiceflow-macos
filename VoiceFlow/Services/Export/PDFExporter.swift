import Foundation
import PDFKit
import AppKit

/// Handles PDF export using macOS native PDFKit
public class PDFExporter: Exporter {
    
    // MARK: - Properties
    
    private var isCancelled = false
    private let exportQueue = DispatchQueue(label: "com.voiceflow.pdfexporter", qos: .userInitiated)
    
    // MARK: - Exporter Protocol
    
    public typealias Configuration = PDFExportConfiguration
    
    public func export(session: TranscriptionSession,
                      configuration: PDFExportConfiguration,
                      progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    progressDelegate?.exportDidUpdateProgress(0.1, currentStep: "Creating PDF document")
                    
                    let pdfDocument = try self.generatePDFDocument(session: session,
                                                                  configuration: configuration,
                                                                  progressDelegate: progressDelegate)
                    
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    guard let data = pdfDocument.dataRepresentation() else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "PDFExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF data"])))
                        return
                    }
                    
                    continuation.resume(returning: .data(data))
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func exportToFile(session: TranscriptionSession,
                            configuration: PDFExportConfiguration,
                            fileURL: URL,
                            progressDelegate: ExportProgressDelegate?) async throws {
        
        let result = try await export(session: session,
                                    configuration: configuration,
                                    progressDelegate: progressDelegate)
        
        switch result {
        case .data(let data):
            do {
                try data.write(to: fileURL)
            } catch {
                throw ExportError.fileWriteError(fileURL, error)
            }
        case .fileURL:
            throw ExportError.invalidSession
        case .error(let error):
            throw error
        }
    }
    
    public func cancelExport() {
        isCancelled = true
    }
    
    // MARK: - Private Methods
    
    private func generatePDFDocument(session: TranscriptionSession,
                                   configuration: PDFExportConfiguration,
                                   progressDelegate: ExportProgressDelegate?) throws -> PDFDocument {
        
        let pdfDocument = PDFDocument()
        var currentPage: PDFPage?
        var currentY: CGFloat = 0
        var pageCount = 0
        
        let pageSize = configuration.pageSize.size
        let contentWidth = pageSize.width - configuration.margins.left - configuration.margins.right
        let contentHeight = pageSize.height - configuration.margins.top - configuration.margins.bottom
        
        // Create attributed string for the entire content
        let attributedContent = NSMutableAttributedString()
        
        // Add title
        if let title = session.metadata.title {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: configuration.fontSize * 1.5),
                .paragraphStyle: createParagraphStyle(alignment: .center)
            ]
            attributedContent.append(NSAttributedString(string: title + "\n\n", attributes: titleAttributes))
        }
        
        // Add metadata if requested
        if configuration.includeMetadata {
            progressDelegate?.exportDidUpdateProgress(0.2, currentStep: "Adding metadata")
            attributedContent.append(createMetadataAttributedString(session: session, fontSize: configuration.fontSize))
            attributedContent.append(NSAttributedString(string: "\n"))
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add main content
        progressDelegate?.exportDidUpdateProgress(0.3, currentStep: "Processing transcription")
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: configuration.fontName, size: configuration.fontSize) ?? NSFont.systemFont(ofSize: configuration.fontSize),
            .paragraphStyle: createParagraphStyle()
        ]
        
        if session.segments.isEmpty {
            attributedContent.append(NSAttributedString(string: session.text, attributes: contentAttributes))
        } else {
            let totalSegments = Double(session.segments.count)
            
            for (index, segment) in session.segments.enumerated() {
                guard !isCancelled else { throw ExportError.cancelled }
                
                let progress = 0.3 + (0.5 * (Double(index) / totalSegments))
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1)")
                
                var segmentText = ""
                
                if configuration.includeTimestamps {
                    segmentText += "[\(formatTimestamp(segment.startTime)) - \(formatTimestamp(segment.endTime))] "
                }
                
                if configuration.includeConfidenceScores {
                    let confidencePercentage = Int(segment.confidence * 100)
                    segmentText += "[\(confidencePercentage)%] "
                }
                
                segmentText += segment.text + "\n\n"
                
                attributedContent.append(NSAttributedString(string: segmentText, attributes: contentAttributes))
            }
        }
        
        // Create PDF pages from attributed string
        progressDelegate?.exportDidUpdateProgress(0.8, currentStep: "Creating PDF pages")
        
        let textStorage = NSTextStorage(attributedString: attributedContent)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        var glyphRange = NSRange(location: 0, length: 0)
        var pageNumber = 1
        
        while glyphRange.location < layoutManager.numberOfGlyphs {
            let textContainer = NSTextContainer(size: CGSize(width: contentWidth, height: contentHeight))
            layoutManager.addTextContainer(textContainer)
            
            // Create a new PDF page
            let page = PDFPage()
            let pageBounds = CGRect(origin: .zero, size: pageSize)
            page.setBounds(pageBounds, for: .mediaBox)
            
            // Draw the text
            let context = NSGraphicsContext.current?.cgContext
            context?.saveGState()
            
            // Draw header if requested
            if configuration.includeHeader {
                drawHeader(on: page, session: session, configuration: configuration)
            }
            
            // Draw main content
            let drawingRect = CGRect(x: configuration.margins.left,
                                   y: configuration.margins.bottom,
                                   width: contentWidth,
                                   height: contentHeight)
            
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawingRect.origin)
            
            // Draw page number if requested
            if configuration.includePageNumbers {
                drawPageNumber(on: page, pageNumber: pageNumber, configuration: configuration)
            }
            
            context?.restoreGState()
            
            // Add page to document
            pdfDocument.insert(page, at: pageNumber - 1)
            
            // Move to next page
            glyphRange = layoutManager.glyphRange(for: textContainer)
            glyphRange.location = NSMaxRange(glyphRange)
            pageNumber += 1
            
            guard !isCancelled else { throw ExportError.cancelled }
        }
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        
        return pdfDocument
    }
    
    private func createMetadataAttributedString(session: TranscriptionSession, fontSize: CGFloat) -> NSAttributedString {
        let metadata = NSMutableAttributedString()
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .paragraphStyle: createParagraphStyle()
        ]
        
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: createParagraphStyle()
        ]
        
        metadata.append(NSAttributedString(string: "METADATA\n", attributes: headerAttributes))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        
        let metadataItems: [(String, String)] = [
            ("Date", dateFormatter.string(from: session.createdAt)),
            ("Duration", session.duration > 0 ? session.duration.humanReadable : "N/A"),
            ("Word Count", "\(session.wordCount)"),
            ("Language", session.language.name),
            ("Speaker", session.metadata.speaker ?? "N/A"),
            ("Location", session.metadata.location ?? "N/A")
        ]
        
        for (key, value) in metadataItems {
            metadata.append(NSAttributedString(string: "\(key): ", attributes: headerAttributes))
            metadata.append(NSAttributedString(string: "\(value)\n", attributes: normalAttributes))
        }
        
        if !session.metadata.tags.isEmpty {
            metadata.append(NSAttributedString(string: "Tags: ", attributes: headerAttributes))
            metadata.append(NSAttributedString(string: session.metadata.tags.joined(separator: ", ") + "\n", attributes: normalAttributes))
        }
        
        return metadata
    }
    
    private func createParagraphStyle(alignment: NSTextAlignment = .left) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        return paragraphStyle
    }
    
    private func drawHeader(on page: PDFPage, session: TranscriptionSession, configuration: PDFExportConfiguration) {
        let bounds = page.bounds(for: .mediaBox)
        let headerRect = CGRect(x: configuration.margins.left,
                               y: bounds.height - configuration.margins.top + 20,
                               width: bounds.width - configuration.margins.left - configuration.margins.right,
                               height: 20)
        
        let headerText = session.metadata.title ?? "Transcription"
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]
        
        let attributedHeader = NSAttributedString(string: headerText, attributes: headerAttributes)
        attributedHeader.draw(in: headerRect)
    }
    
    private func drawPageNumber(on page: PDFPage, pageNumber: Int, configuration: PDFExportConfiguration) {
        let bounds = page.bounds(for: .mediaBox)
        let pageNumberRect = CGRect(x: configuration.margins.left,
                                   y: configuration.margins.bottom - 30,
                                   width: bounds.width - configuration.margins.left - configuration.margins.right,
                                   height: 20)
        
        let pageNumberText = "Page \(pageNumber)"
        let pageNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray,
            .paragraphStyle: createParagraphStyle(alignment: .center)
        ]
        
        let attributedPageNumber = NSAttributedString(string: pageNumberText, attributes: pageNumberAttributes)
        attributedPageNumber.draw(in: pageNumberRect)
    }
    
    private func formatTimestamp(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - PDF Export Extensions

extension PDFExporter {
    /// Export with custom annotations
    public func exportWithAnnotations(session: TranscriptionSession,
                                    configuration: PDFExportConfiguration,
                                    annotations: [TranscriptionAnnotation],
                                    progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        // First create the base PDF
        let basePDF = try await export(session: session,
                                     configuration: configuration,
                                     progressDelegate: progressDelegate)
        
        guard case .data(let pdfData) = basePDF,
              let pdfDocument = PDFDocument(data: pdfData) else {
            throw ExportError.encodingError(NSError(domain: "PDFExporter",
                                                   code: 2,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF with annotations"]))
        }
        
        // Add annotations
        for annotation in annotations {
            // Implementation would add PDF annotations based on the annotation data
            // This is a placeholder for the actual implementation
        }
        
        guard let annotatedData = pdfDocument.dataRepresentation() else {
            throw ExportError.encodingError(NSError(domain: "PDFExporter",
                                                   code: 3,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to generate annotated PDF data"]))
        }
        
        return .data(annotatedData)
    }
}

// MARK: - Supporting Types

public struct TranscriptionAnnotation {
    let text: String
    let timestamp: TimeInterval
    let type: AnnotationType
    
    public enum AnnotationType {
        case note
        case highlight
        case bookmark
    }
}