import Foundation

/// Handles plain text export
public class TextExporter: Exporter {
    
    // MARK: - Properties
    
    private var isCancelled = false
    private let exportQueue = DispatchQueue(label: "com.voiceflow.textexporter", qos: .userInitiated)
    
    // MARK: - Exporter Protocol
    
    public typealias Configuration = TextExportConfiguration
    
    public func export(session: TranscriptionSession,
                      configuration: TextExportConfiguration,
                      progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    let content = try self.generateTextContent(session: session,
                                                              configuration: configuration,
                                                              progressDelegate: progressDelegate)
                    
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    guard let data = content.data(using: .utf8) else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "TextExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode text as UTF-8"])))
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
                            configuration: TextExportConfiguration,
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
    
    private func generateTextContent(session: TranscriptionSession,
                                   configuration: TextExportConfiguration,
                                   progressDelegate: ExportProgressDelegate?) throws -> String {
        
        var content = ""
        
        // Add metadata if requested
        if configuration.includeMetadata {
            progressDelegate?.exportDidUpdateProgress(0.1, currentStep: "Adding metadata")
            content += generateMetadataSection(session: session)
            content += "\n" + String(repeating: "-", count: 80) + "\n\n"
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add transcription content
        progressDelegate?.exportDidUpdateProgress(0.3, currentStep: "Processing transcription")
        
        if session.segments.isEmpty {
            // If no segments, just add the full text
            content += session.text
        } else {
            // Process segments
            let totalSegments = Double(session.segments.count)
            
            for (index, segment) in session.segments.enumerated() {
                guard !isCancelled else { throw ExportError.cancelled }
                
                let progress = 0.3 + (0.6 * (Double(index) / totalSegments))
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1) of \(session.segments.count)")
                
                // Add timestamp if requested
                if configuration.includeTimestamps {
                    content += "[\(formatTimestamp(segment.startTime)) - \(formatTimestamp(segment.endTime))] "
                }
                
                // Add confidence score if requested
                if configuration.includeConfidenceScores {
                    let confidencePercentage = Int(segment.confidence * 100)
                    content += "[\(confidencePercentage)%] "
                }
                
                // Add segment text
                content += segment.text
                
                // Add line breaks between segments if requested
                if configuration.lineBreaksBetweenSegments {
                    content += "\n\n"
                } else {
                    content += " "
                }
            }
        }
        
        // Clean up trailing whitespace
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        
        return content
    }
    
    private func generateMetadataSection(session: TranscriptionSession) -> String {
        var metadata = "TRANSCRIPTION METADATA\n"
        metadata += "=====================\n\n"
        
        // Date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        metadata += "Date: \(dateFormatter.string(from: session.createdAt))\n"
        
        // Duration
        if session.duration > 0 {
            metadata += "Duration: \(session.duration.humanReadable)\n"
        }
        
        // Word count
        metadata += "Word Count: \(session.wordCount)\n"
        
        // Language
        metadata += "Language: \(session.language.name)\n"
        
        // Title
        if let title = session.metadata.title {
            metadata += "Title: \(title)\n"
        }
        
        // Speaker
        if let speaker = session.metadata.speaker {
            metadata += "Speaker: \(speaker)\n"
        }
        
        // Location
        if let location = session.metadata.location {
            metadata += "Location: \(location)\n"
        }
        
        // Tags
        if !session.metadata.tags.isEmpty {
            metadata += "Tags: \(session.metadata.tags.joined(separator: ", "))\n"
        }
        
        // Average confidence
        if !session.segments.isEmpty {
            let averageConfidence = session.segments.map { $0.confidence }.reduce(0, +) / Double(session.segments.count)
            let confidencePercentage = Int(averageConfidence * 100)
            metadata += "Average Confidence: \(confidencePercentage)%\n"
        }
        
        // Custom fields
        for (key, value) in session.metadata.customFields {
            metadata += "\(key): \(value)\n"
        }
        
        return metadata
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

// MARK: - Text Export Extensions

extension TextExporter {
    /// Export with custom formatting
    public func exportWithCustomFormat(session: TranscriptionSession,
                                     formatter: @escaping (TranscriptionSegment) -> String,
                                     progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                var content = ""
                let totalSegments = Double(session.segments.count)
                
                for (index, segment) in session.segments.enumerated() {
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    let progress = Double(index) / totalSegments
                    progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Formatting segment \(index + 1)")
                    
                    content += formatter(segment) + "\n"
                }
                
                guard let data = content.data(using: .utf8) else {
                    continuation.resume(throwing: ExportError.encodingError(NSError(domain: "TextExporter",
                                                                                   code: 1,
                                                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to encode text as UTF-8"])))
                    return
                }
                
                continuation.resume(returning: .data(data))
            }
        }
    }
}