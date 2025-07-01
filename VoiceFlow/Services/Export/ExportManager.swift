import Foundation

/// Main export manager that coordinates all export operations
public class ExportManager {
    
    // MARK: - Properties
    
    private let textExporter: TextExporter
    private let markdownExporter: MarkdownExporter
    private let docxExporter: DocxExporter
    private let pdfExporter: PDFExporter
    private let srtExporter: SRTExporter
    
    private var activeExporters: Set<UUID> = []
    private let exportQueue = DispatchQueue(label: "com.voiceflow.export", qos: .userInitiated)
    
    // MARK: - Export Format
    
    public enum ExportFormat: String, CaseIterable {
        case text = "txt"
        case markdown = "md"
        case docx = "docx"
        case pdf = "pdf"
        case srt = "srt"
        
        var displayName: String {
            switch self {
            case .text: return "Plain Text"
            case .markdown: return "Markdown"
            case .docx: return "Microsoft Word"
            case .pdf: return "PDF"
            case .srt: return "Subtitles (SRT)"
            }
        }
        
        var fileExtension: String {
            return self.rawValue
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        self.textExporter = TextExporter()
        self.markdownExporter = MarkdownExporter()
        self.docxExporter = DocxExporter()
        self.pdfExporter = PDFExporter()
        self.srtExporter = SRTExporter()
    }
    
    // MARK: - Export Methods
    
    /// Export a transcription session to the specified format
    public func export(session: TranscriptionSession,
                      format: ExportFormat,
                      configuration: ExportConfiguration? = nil,
                      progressDelegate: ExportProgressDelegate? = nil) async throws -> ExportResult {
        
        let exportId = UUID()
        activeExporters.insert(exportId)
        defer { activeExporters.remove(exportId) }
        
        progressDelegate?.exportDidStart()
        
        do {
            let result: ExportResult
            
            switch format {
            case .text:
                let config = configuration as? TextExportConfiguration ?? TextExportConfiguration()
                result = try await textExporter.export(session: session,
                                                      configuration: config,
                                                      progressDelegate: progressDelegate)
                
            case .markdown:
                let config = configuration as? MarkdownExportConfiguration ?? MarkdownExportConfiguration()
                result = try await markdownExporter.export(session: session,
                                                          configuration: config,
                                                          progressDelegate: progressDelegate)
                
            case .docx:
                let config = configuration as? DocxExportConfiguration ?? DocxExportConfiguration()
                result = try await docxExporter.export(session: session,
                                                      configuration: config,
                                                      progressDelegate: progressDelegate)
                
            case .pdf:
                let config = configuration as? PDFExportConfiguration ?? PDFExportConfiguration()
                result = try await pdfExporter.export(session: session,
                                                     configuration: config,
                                                     progressDelegate: progressDelegate)
                
            case .srt:
                let config = configuration as? SRTExportConfiguration ?? SRTExportConfiguration()
                result = try await srtExporter.export(session: session,
                                                     configuration: config,
                                                     progressDelegate: progressDelegate)
            }
            
            progressDelegate?.exportDidComplete(result: result)
            return result
            
        } catch let error as ExportError {
            progressDelegate?.exportDidFail(error: error)
            throw error
        } catch {
            let exportError = ExportError.encodingError(error)
            progressDelegate?.exportDidFail(error: exportError)
            throw exportError
        }
    }
    
    /// Export to a specific file URL
    public func exportToFile(session: TranscriptionSession,
                            format: ExportFormat,
                            fileURL: URL,
                            configuration: ExportConfiguration? = nil,
                            progressDelegate: ExportProgressDelegate? = nil) async throws {
        
        let exportId = UUID()
        activeExporters.insert(exportId)
        defer { activeExporters.remove(exportId) }
        
        progressDelegate?.exportDidStart()
        
        do {
            switch format {
            case .text:
                let config = configuration as? TextExportConfiguration ?? TextExportConfiguration()
                try await textExporter.exportToFile(session: session,
                                                   configuration: config,
                                                   fileURL: fileURL,
                                                   progressDelegate: progressDelegate)
                
            case .markdown:
                let config = configuration as? MarkdownExportConfiguration ?? MarkdownExportConfiguration()
                try await markdownExporter.exportToFile(session: session,
                                                       configuration: config,
                                                       fileURL: fileURL,
                                                       progressDelegate: progressDelegate)
                
            case .docx:
                let config = configuration as? DocxExportConfiguration ?? DocxExportConfiguration()
                try await docxExporter.exportToFile(session: session,
                                                   configuration: config,
                                                   fileURL: fileURL,
                                                   progressDelegate: progressDelegate)
                
            case .pdf:
                let config = configuration as? PDFExportConfiguration ?? PDFExportConfiguration()
                try await pdfExporter.exportToFile(session: session,
                                                  configuration: config,
                                                  fileURL: fileURL,
                                                  progressDelegate: progressDelegate)
                
            case .srt:
                let config = configuration as? SRTExportConfiguration ?? SRTExportConfiguration()
                try await srtExporter.exportToFile(session: session,
                                                  configuration: config,
                                                  fileURL: fileURL,
                                                  progressDelegate: progressDelegate)
            }
            
            progressDelegate?.exportDidComplete(result: .fileURL(fileURL))
            
        } catch let error as ExportError {
            progressDelegate?.exportDidFail(error: error)
            throw error
        } catch {
            let exportError = ExportError.fileWriteError(fileURL, error)
            progressDelegate?.exportDidFail(error: exportError)
            throw exportError
        }
    }
    
    /// Cancel all active export operations
    public func cancelAllExports() {
        textExporter.cancelExport()
        markdownExporter.cancelExport()
        docxExporter.cancelExport()
        pdfExporter.cancelExport()
        srtExporter.cancelExport()
        activeExporters.removeAll()
    }
    
    // MARK: - Utility Methods
    
    /// Get suggested filename for export
    public func suggestedFilename(for session: TranscriptionSession, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = dateFormatter.string(from: session.createdAt)
        
        let baseFilename = session.metadata.title ?? "Transcription"
        let sanitizedFilename = baseFilename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\"", with: "")
        
        return "\(sanitizedFilename)_\(dateString).\(format.fileExtension)"
    }
    
    /// Get available export formats for a session
    public func availableFormats(for session: TranscriptionSession) -> [ExportFormat] {
        var formats = ExportFormat.allCases
        
        // Remove SRT if session doesn't have timing information
        if session.segments.isEmpty || session.segments.allSatisfy({ $0.words.isEmpty }) {
            formats.removeAll { $0 == .srt }
        }
        
        return formats
    }
    
    /// Estimate export size in bytes
    public func estimateExportSize(session: TranscriptionSession, format: ExportFormat) -> Int {
        let baseSize = session.text.utf8.count
        
        switch format {
        case .text:
            return baseSize + (session.metadata.title?.utf8.count ?? 0) + 1000 // Metadata overhead
        case .markdown:
            return baseSize * 2 // Account for markdown formatting
        case .docx:
            return baseSize * 3 // DOCX overhead
        case .pdf:
            return baseSize * 4 // PDF overhead
        case .srt:
            return baseSize * 2 // Timing information
        }
    }
    
    /// Validate export configuration
    public func validateConfiguration(_ configuration: ExportConfiguration, for format: ExportFormat) -> Result<Void, ExportError> {
        switch format {
        case .srt:
            if let srtConfig = configuration as? SRTExportConfiguration {
                if srtConfig.maxCharactersPerLine < 10 {
                    return .failure(.configurationError("Maximum characters per line must be at least 10"))
                }
                if srtConfig.maxLinesPerSubtitle < 1 {
                    return .failure(.configurationError("Maximum lines per subtitle must be at least 1"))
                }
            }
        case .pdf:
            if let pdfConfig = configuration as? PDFExportConfiguration {
                if pdfConfig.fontSize < 6 || pdfConfig.fontSize > 72 {
                    return .failure(.configurationError("Font size must be between 6 and 72 points"))
                }
            }
        default:
            break
        }
        
        return .success(())
    }
}

// MARK: - Export Manager Extensions

extension ExportManager {
    /// Batch export to multiple formats
    public func batchExport(session: TranscriptionSession,
                           formats: [ExportFormat],
                           outputDirectory: URL,
                           configurations: [ExportFormat: ExportConfiguration] = [:],
                           progressDelegate: ExportProgressDelegate? = nil) async -> [ExportFormat: Result<URL, ExportError>] {
        
        var results: [ExportFormat: Result<URL, ExportError>] = [:]
        let totalFormats = Double(formats.count)
        
        for (index, format) in formats.enumerated() {
            let progress = Double(index) / totalFormats
            progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Exporting to \(format.displayName)")
            
            let filename = suggestedFilename(for: session, format: format)
            let fileURL = outputDirectory.appendingPathComponent(filename)
            
            do {
                let configuration = configurations[format]
                try await exportToFile(session: session,
                                     format: format,
                                     fileURL: fileURL,
                                     configuration: configuration,
                                     progressDelegate: nil)
                results[format] = .success(fileURL)
            } catch let error as ExportError {
                results[format] = .failure(error)
            } catch {
                results[format] = .failure(.encodingError(error))
            }
        }
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        return results
    }
}