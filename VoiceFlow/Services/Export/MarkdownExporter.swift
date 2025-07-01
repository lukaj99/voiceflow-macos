import Foundation

/// Handles Markdown export with metadata
public class MarkdownExporter: Exporter {
    
    // MARK: - Properties
    
    private var isCancelled = false
    private let exportQueue = DispatchQueue(label: "com.voiceflow.markdownexporter", qos: .userInitiated)
    
    // MARK: - Exporter Protocol
    
    public typealias Configuration = MarkdownExportConfiguration
    
    public func export(session: TranscriptionSession,
                      configuration: MarkdownExportConfiguration,
                      progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    let content = try self.generateMarkdownContent(session: session,
                                                                  configuration: configuration,
                                                                  progressDelegate: progressDelegate)
                    
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    guard let data = content.data(using: .utf8) else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "MarkdownExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode markdown as UTF-8"])))
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
                            configuration: MarkdownExportConfiguration,
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
    
    private func generateMarkdownContent(session: TranscriptionSession,
                                       configuration: MarkdownExportConfiguration,
                                       progressDelegate: ExportProgressDelegate?) throws -> String {
        
        var content = ""
        
        // Add title
        let title = session.metadata.title ?? "Transcription"
        content += "# \(title)\n\n"
        
        // Add metadata if requested
        if configuration.includeMetadata {
            progressDelegate?.exportDidUpdateProgress(0.1, currentStep: "Adding metadata")
            content += generateMetadataSection(session: session)
            content += "\n---\n\n"
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add table of contents if requested
        if configuration.includeTableOfContents && !session.segments.isEmpty {
            progressDelegate?.exportDidUpdateProgress(0.2, currentStep: "Generating table of contents")
            content += generateTableOfContents(session: session, configuration: configuration)
            content += "\n---\n\n"
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add transcription content
        progressDelegate?.exportDidUpdateProgress(0.3, currentStep: "Processing transcription")
        content += "## Transcription\n\n"
        
        if session.segments.isEmpty {
            // If no segments, just add the full text
            content += session.text + "\n"
        } else {
            // Process segments
            let totalSegments = Double(session.segments.count)
            
            for (index, segment) in session.segments.enumerated() {
                guard !isCancelled else { throw ExportError.cancelled }
                
                let progress = 0.3 + (0.6 * (Double(index) / totalSegments))
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1) of \(session.segments.count)")
                
                // Add segment header if timestamps are included
                if configuration.includeTimestamps {
                    let headerLevel = String(repeating: "#", count: configuration.segmentHeaderLevel)
                    content += "\(headerLevel) \(formatTimestamp(segment.startTime)) - \(formatTimestamp(segment.endTime))\n\n"
                }
                
                // Add confidence score if requested
                if configuration.includeConfidenceScores {
                    let confidencePercentage = Int(segment.confidence * 100)
                    content += "> **Confidence:** \(confidencePercentage)%\n\n"
                }
                
                // Add segment text
                content += segment.text + "\n\n"
            }
        }
        
        // Add footer
        content += "\n---\n\n"
        content += generateFooter(session: session)
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        
        return content
    }
    
    private func generateMetadataSection(session: TranscriptionSession) -> String {
        var metadata = "## Metadata\n\n"
        
        // Create metadata table
        metadata += "| Property | Value |\n"
        metadata += "|----------|-------|\n"
        
        // Date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        metadata += "| **Date** | \(dateFormatter.string(from: session.createdAt)) |\n"
        
        // Duration
        if session.duration > 0 {
            metadata += "| **Duration** | \(session.duration.humanReadable) |\n"
        }
        
        // Word count
        metadata += "| **Word Count** | \(session.wordCount) |\n"
        
        // Language
        metadata += "| **Language** | \(session.language.name) |\n"
        
        // Speaker
        if let speaker = session.metadata.speaker {
            metadata += "| **Speaker** | \(speaker) |\n"
        }
        
        // Location
        if let location = session.metadata.location {
            metadata += "| **Location** | \(location) |\n"
        }
        
        // Tags
        if !session.metadata.tags.isEmpty {
            let tags = session.metadata.tags.map { "`\($0)`" }.joined(separator: ", ")
            metadata += "| **Tags** | \(tags) |\n"
        }
        
        // Average confidence
        if !session.segments.isEmpty {
            let averageConfidence = session.segments.map { $0.confidence }.reduce(0, +) / Double(session.segments.count)
            let confidencePercentage = Int(averageConfidence * 100)
            metadata += "| **Average Confidence** | \(confidencePercentage)% |\n"
        }
        
        // Custom fields
        for (key, value) in session.metadata.customFields {
            metadata += "| **\(key)** | \(value) |\n"
        }
        
        return metadata
    }
    
    private func generateTableOfContents(session: TranscriptionSession,
                                       configuration: MarkdownExportConfiguration) -> String {
        var toc = "## Table of Contents\n\n"
        
        toc += "1. [Metadata](#metadata)\n"
        toc += "2. [Transcription](#transcription)\n"
        
        if configuration.includeTimestamps && !session.segments.isEmpty {
            toc += "   - Segments:\n"
            
            for (index, segment) in session.segments.enumerated().prefix(10) {
                let timestamp = formatTimestamp(segment.startTime)
                let anchor = timestamp.replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                
                let preview = String(segment.text.prefix(50))
                    .replacingOccurrences(of: "\n", with: " ")
                let ellipsis = segment.text.count > 50 ? "..." : ""
                
                toc += "     - [\(timestamp)](#\(anchor)) - \(preview)\(ellipsis)\n"
            }
            
            if session.segments.count > 10 {
                toc += "     - _...and \(session.segments.count - 10) more segments_\n"
            }
        }
        
        return toc
    }
    
    private func generateFooter(session: TranscriptionSession) -> String {
        var footer = "_Generated by VoiceFlow_\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        footer += "_Export date: \(dateFormatter.string(from: Date()))_\n"
        
        if let sessionId = session.id.uuidString.prefix(8) {
            footer += "_Session ID: \(sessionId)..._\n"
        }
        
        return footer
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

// MARK: - Markdown Export Extensions

extension MarkdownExporter {
    /// Export as GitHub Flavored Markdown
    public func exportAsGFM(session: TranscriptionSession,
                           includeTaskList: Bool = false,
                           progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        var configuration = MarkdownExportConfiguration()
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    var content = try self.generateMarkdownContent(session: session,
                                                                  configuration: configuration,
                                                                  progressDelegate: progressDelegate)
                    
                    // Add GitHub specific features
                    if includeTaskList {
                        content += "\n## Action Items\n\n"
                        content += "- [ ] Review transcription for accuracy\n"
                        content += "- [ ] Extract key points\n"
                        content += "- [ ] Share with stakeholders\n"
                    }
                    
                    // Add collapsible sections for long segments
                    if session.segments.count > 20 {
                        content = self.wrapLongSectionsInDetails(content)
                    }
                    
                    guard let data = content.data(using: .utf8) else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "MarkdownExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode GFM as UTF-8"])))
                        return
                    }
                    
                    continuation.resume(returning: .data(data))
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func wrapLongSectionsInDetails(_ content: String) -> String {
        // This is a simplified implementation
        // In a real implementation, you would parse the markdown more carefully
        return content
    }
}