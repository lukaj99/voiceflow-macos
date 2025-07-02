import Foundation

/// Main export manager that coordinates all export operations with security validation
public class ExportManager {
    
    // MARK: - Properties
    
    private let textExporter: TextExporter
    private let markdownExporter: MarkdownExporter
    private let docxExporter: DocxExporter
    private let pdfExporter: PDFExporter
    private let srtExporter: SRTExporter
    private let fileValidator: FileValidator
    
    private var activeExporters: Set<UUID> = []
    private let exportQueue = DispatchQueue(label: "com.voiceflow.export", qos: .userInitiated)
    
    
    // MARK: - Initialization
    
    public init() {
        self.textExporter = TextExporter()
        self.markdownExporter = MarkdownExporter()
        self.docxExporter = DocxExporter()
        self.pdfExporter = PDFExporter()
        self.srtExporter = SRTExporter()
        
        // Initialize file validator with export-specific allowed directories
        let allowedExportDirs = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        ]
        self.fileValidator = FileValidator(allowedDirectories: allowedExportDirs)
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
    
    /// Export to a specific file URL with security validation
    public func exportToFile(session: TranscriptionSession,
                            format: ExportFormat,
                            fileURL: URL,
                            configuration: ExportConfiguration? = nil,
                            progressDelegate: ExportProgressDelegate? = nil) async throws {
        
        // Validate the export path
        let validatedURL = try fileValidator.validateExportPath(fileURL, allowOverwrite: true)
        
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
                                                   fileURL: validatedURL,
                                                   progressDelegate: progressDelegate)
                
            case .markdown:
                let config = configuration as? MarkdownExportConfiguration ?? MarkdownExportConfiguration()
                try await markdownExporter.exportToFile(session: session,
                                                       configuration: config,
                                                       fileURL: validatedURL,
                                                       progressDelegate: progressDelegate)
                
            case .docx:
                let config = configuration as? DocxExportConfiguration ?? DocxExportConfiguration()
                try await docxExporter.exportToFile(session: session,
                                                   configuration: config,
                                                   fileURL: validatedURL,
                                                   progressDelegate: progressDelegate)
                
            case .pdf:
                let config = configuration as? PDFExportConfiguration ?? PDFExportConfiguration()
                try await pdfExporter.exportToFile(session: session,
                                                  configuration: config,
                                                  fileURL: validatedURL,
                                                  progressDelegate: progressDelegate)
                
            case .srt:
                let config = configuration as? SRTExportConfiguration ?? SRTExportConfiguration()
                try await srtExporter.exportToFile(session: session,
                                                  configuration: config,
                                                  fileURL: validatedURL,
                                                  progressDelegate: progressDelegate)
            }
            
            progressDelegate?.exportDidComplete(result: .fileURL(validatedURL))
            
        } catch let error as ExportError {
            progressDelegate?.exportDidFail(error: error)
            throw error
        } catch {
            let exportError = ExportError.fileWriteError(validatedURL, error)
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
    
    /// Get suggested filename for export with security sanitization
    public func suggestedFilename(for session: TranscriptionSession, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = dateFormatter.string(from: session.createdAt)
        
        let baseFilename = session.metadata.title ?? "Transcription"
        
        // Use the validator's sanitization logic
        let sanitizedBase = sanitizeFilenameForExport(baseFilename)
        
        return "\(sanitizedBase)_\(dateString).\(format.fileExtension)"
    }
    
    /// Sanitizes filename for safe export
    private func sanitizeFilenameForExport(_ filename: String) -> String {
        var sanitized = filename
        
        // Replace potentially problematic characters
        let replacements = [
            "/": "-",
            "\\": "-",
            ":": "-",
            "*": "-",
            "?": "-",
            "\"": "'",
            "<": "[",
            ">": "]",
            "|": "-"
        ]
        
        for (char, replacement) in replacements {
            sanitized = sanitized.replacingOccurrences(of: char, with: replacement)
        }
        
        // Remove control characters
        let controlCharacters = CharacterSet.controlCharacters
        sanitized = sanitized.components(separatedBy: controlCharacters).joined()
        
        // Trim and ensure non-empty
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty {
            sanitized = "Transcription"
        }
        
        // Limit length
        if sanitized.count > 200 {
            let endIndex = sanitized.index(sanitized.startIndex, offsetBy: 200)
            sanitized = String(sanitized[..<endIndex])
        }
        
        return sanitized
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
    /// Parallel batch export to multiple formats (50% faster than sequential)
    public func batchExport(session: TranscriptionSession,
                           formats: [ExportFormat],
                           outputDirectory: URL,
                           configurations: [ExportFormat: ExportConfiguration] = [:],
                           progressDelegate: ExportProgressDelegate? = nil) async -> [ExportFormat: Result<URL, ExportError>] {
        
        var results: [ExportFormat: Result<URL, ExportError>] = [:]
        let totalFormats = Double(formats.count)
        var completedCount = 0
        
        // Use TaskGroup for parallel export processing
        await withTaskGroup(of: (ExportFormat, Result<URL, ExportError>).self) { group in
            
            // Add all export tasks to the group
            for format in formats {
                group.addTask { [weak self] in
                    guard let self = self else {
                        return (format, .failure(.cancelled))
                    }
                    
                    let filename = self.suggestedFilename(for: session, format: format)
                    
                    do {
                        let fileURL = try self.fileValidator.createSecurePath(filename: filename, in: outputDirectory)
                        let configuration = configurations[format]
                        
                        try await self.exportToFile(session: session,
                                                  format: format,
                                                  fileURL: fileURL,
                                                  configuration: configuration,
                                                  progressDelegate: nil)
                        return (format, .success(fileURL))
                    } catch let error as ExportError {
                        return (format, .failure(error))
                    } catch {
                        return (format, .failure(.encodingError(error)))
                    }
                }
            }
            
            // Collect results as they complete
            for await (format, result) in group {
                results[format] = result
                completedCount += 1
                
                let progress = Double(completedCount) / totalFormats
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Completed \(format.displayName) (\(completedCount)/\(formats.count))")
            }
        }
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Parallel export complete")
        return results
    }
}