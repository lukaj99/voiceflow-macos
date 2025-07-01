import Foundation
import UniformTypeIdentifiers

/// Handles DOCX export
/// Note: This is a simplified implementation. For production use, consider using a library like DocX
public class DocxExporter: Exporter {
    
    // MARK: - Properties
    
    private var isCancelled = false
    private let exportQueue = DispatchQueue(label: "com.voiceflow.docxexporter", qos: .userInitiated)
    
    // MARK: - Exporter Protocol
    
    public typealias Configuration = DocxExportConfiguration
    
    public func export(session: TranscriptionSession,
                      configuration: DocxExportConfiguration,
                      progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    progressDelegate?.exportDidUpdateProgress(0.1, currentStep: "Creating DOCX structure")
                    
                    // For this implementation, we'll create a simple RTF that can be opened as DOCX
                    // In production, use a proper DOCX library
                    let rtfContent = try self.generateRTFContent(session: session,
                                                                configuration: configuration,
                                                                progressDelegate: progressDelegate)
                    
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    guard let data = rtfContent.data(using: .utf8) else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "DocxExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode RTF as UTF-8"])))
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
                            configuration: DocxExportConfiguration,
                            fileURL: URL,
                            progressDelegate: ExportProgressDelegate?) async throws {
        
        let result = try await export(session: session,
                                    configuration: configuration,
                                    progressDelegate: progressDelegate)
        
        switch result {
        case .data(let data):
            do {
                // Change extension to .rtf for now
                let rtfURL = fileURL.deletingPathExtension().appendingPathExtension("rtf")
                try data.write(to: rtfURL)
                
                // In a production implementation, you would:
                // 1. Create proper DOCX structure with XML files
                // 2. Zip the structure
                // 3. Save with .docx extension
                
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
    
    private func generateRTFContent(session: TranscriptionSession,
                                   configuration: DocxExportConfiguration,
                                   progressDelegate: ExportProgressDelegate?) throws -> String {
        
        var rtf = "{\\rtf1\\ansi\\deff0 {\\fonttbl{\\f0 \\fnil \\fcharset0 \(configuration.fontName);}}\n"
        rtf += "\\f0\\fs\(Int(configuration.fontSize * 2))\n" // RTF uses half-points
        
        // Add header if metadata is included
        if configuration.includeMetadata {
            progressDelegate?.exportDidUpdateProgress(0.2, currentStep: "Adding metadata")
            rtf += try generateRTFMetadata(session: session, configuration: configuration)
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add main content
        progressDelegate?.exportDidUpdateProgress(0.3, currentStep: "Processing transcription")
        
        let title = session.metadata.title ?? "Transcription"
        rtf += "\\par\\b\\fs\(Int(configuration.fontSize * 3)) \(escapeRTF(title))\\b0\\fs\(Int(configuration.fontSize * 2))\\par\\par\n"
        
        if session.segments.isEmpty {
            rtf += "\(escapeRTF(session.text))\\par\n"
        } else {
            let totalSegments = Double(session.segments.count)
            
            for (index, segment) in session.segments.enumerated() {
                guard !isCancelled else { throw ExportError.cancelled }
                
                let progress = 0.3 + (0.6 * (Double(index) / totalSegments))
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1)")
                
                if configuration.includeTimestamps {
                    rtf += "\\b [\(formatTimestamp(segment.startTime)) - \(formatTimestamp(segment.endTime))]\\b0 "
                }
                
                if configuration.includeConfidenceScores {
                    let confidencePercentage = Int(segment.confidence * 100)
                    rtf += "\\i [\(confidencePercentage)%]\\i0 "
                }
                
                rtf += "\(escapeRTF(segment.text))\\par\\par\n"
            }
        }
        
        // Add page numbers if requested
        if configuration.includePageNumbers {
            rtf += "\\par\\qc\\f0\\fs20 Page \\chpgn\\par\n"
        }
        
        rtf += "}"
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        
        return rtf
    }
    
    private func generateRTFMetadata(session: TranscriptionSession,
                                    configuration: DocxExportConfiguration) throws -> String {
        
        var metadata = "\\par\\b TRANSCRIPTION METADATA\\b0\\par\n"
        metadata += "\\par\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        
        metadata += "Date: \(escapeRTF(dateFormatter.string(from: session.createdAt)))\\par\n"
        
        if session.duration > 0 {
            metadata += "Duration: \(escapeRTF(session.duration.humanReadable))\\par\n"
        }
        
        metadata += "Word Count: \(session.wordCount)\\par\n"
        metadata += "Language: \(escapeRTF(session.language.name))\\par\n"
        
        if let title = session.metadata.title {
            metadata += "Title: \(escapeRTF(title))\\par\n"
        }
        
        if let speaker = session.metadata.speaker {
            metadata += "Speaker: \(escapeRTF(speaker))\\par\n"
        }
        
        if let location = session.metadata.location {
            metadata += "Location: \(escapeRTF(location))\\par\n"
        }
        
        if !session.metadata.tags.isEmpty {
            metadata += "Tags: \(escapeRTF(session.metadata.tags.joined(separator: ", ")))\\par\n"
        }
        
        metadata += "\\par\\par\n"
        
        return metadata
    }
    
    private func escapeRTF(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\par ")
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

// MARK: - DOCX Structure (For Reference)

/*
 A proper DOCX implementation would create:
 
 1. [Content_Types].xml
 2. _rels/.rels
 3. word/_rels/document.xml.rels
 4. word/document.xml (main content)
 5. word/styles.xml
 6. word/settings.xml
 7. word/fontTable.xml
 8. docProps/app.xml
 9. docProps/core.xml
 
 Then zip all files with proper structure.
 
 For production use, consider using:
 - https://github.com/shinjukunian/DocX
 - Or create a server-side solution using python-docx or similar
 */

// MARK: - Future Enhancement

extension DocxExporter {
    /// Create a proper DOCX file using XML structure
    /// This is a placeholder for a full implementation
    private func createProperDocx(session: TranscriptionSession,
                                 configuration: DocxExportConfiguration) throws -> Data {
        // This would involve:
        // 1. Creating XML documents for each required component
        // 2. Building the proper directory structure
        // 3. Zipping the contents
        // 4. Returning the zip data
        
        // For now, we return empty data
        // In production, implement full DOCX creation or use a library
        return Data()
    }
}