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
        
        // Use optimized string builder to eliminate repeated concatenations
        let estimatedSize = session.text.count + (session.segments.count * 100) + 2000
        let content = MemoryOptimizer.shared.buildString(estimatedCapacity: estimatedSize) { builder in
            
        // Add metadata if requested
        if configuration.includeMetadata {
            progressDelegate?.exportDidUpdateProgress(0.1, currentStep: "Adding metadata")
            builder.append(generateMetadataSection(session: session))
            builder.append("\n")
            builder.append(String(repeating: "-", count: 80))
            builder.append("\n\n")
        }
        
        guard !isCancelled else { throw ExportError.cancelled }
        
        // Add transcription content
        progressDelegate?.exportDidUpdateProgress(0.3, currentStep: "Processing transcription")
        
        if session.segments.isEmpty {
            // If no segments, just add the full text
            builder.append(session.text)
        } else {
            // Process segments efficiently
            let totalSegments = Double(session.segments.count)
            
            for (index, segment) in session.segments.enumerated() {
                guard !isCancelled else { throw ExportError.cancelled }
                
                let progress = 0.3 + (0.6 * (Double(index) / totalSegments))
                progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1) of \(session.segments.count)")
                
                // Add timestamp if requested
                if configuration.includeTimestamps {
                    builder.append("[")
                    builder.append(formatTimestamp(segment.startTime))
                    builder.append(" - ")
                    builder.append(formatTimestamp(segment.endTime))
                    builder.append("] ")
                }
                
                // Add confidence score if requested
                if configuration.includeConfidenceScores {
                    let confidencePercentage = Int(segment.confidence * 100)
                    builder.append("[")
                    builder.append(String(confidencePercentage))
                    builder.append("%] ")
                }
                
                // Add segment text
                builder.append(segment.text)
                
                // Add line breaks between segments if requested
                if configuration.lineBreaksBetweenSegments {
                    builder.append("\n\n")
                } else {
                    builder.append(" ")
                }
            }
        }
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        }
        
        // Return cleaned content
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateMetadataSection(session: TranscriptionSession) -> String {
        // Use optimized string builder for metadata generation
        return MemoryOptimizer.shared.buildString(estimatedCapacity: 1000) { builder in
            builder.append("TRANSCRIPTION METADATA\n")
            builder.append("=====================\n\n")
            
            // Date and time
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .medium
            builder.append("Date: ")
            builder.append(dateFormatter.string(from: session.createdAt))
            builder.append("\n")
            
            // Duration
            if session.duration > 0 {
                builder.append("Duration: ")
                builder.append(session.duration.humanReadable)
                builder.append("\n")
            }
            
            // Word count
            builder.append("Word Count: ")
            builder.append(String(session.wordCount))
            builder.append("\n")
            
            // Language
            builder.append("Language: ")
            builder.append(session.language.name)
            builder.append("\n")
            
            // Title
            if let title = session.metadata.title {
                builder.append("Title: ")
                builder.append(title)
                builder.append("\n")
            }
            
            // Speaker
            if let speaker = session.metadata.speaker {
                builder.append("Speaker: ")
                builder.append(speaker)
                builder.append("\n")
            }
            
            // Location
            if let location = session.metadata.location {
                builder.append("Location: ")
                builder.append(location)
                builder.append("\n")
            }
            
            // Tags
            if !session.metadata.tags.isEmpty {
                builder.append("Tags: ")
                builder.append(session.metadata.tags.joined(separator: ", "))
                builder.append("\n")
            }
            
            // Average confidence
            if !session.segments.isEmpty {
                let averageConfidence = session.segments.map { $0.confidence }.reduce(0, +) / Double(session.segments.count)
                let confidencePercentage = Int(averageConfidence * 100)
                builder.append("Average Confidence: ")
                builder.append(String(confidencePercentage))
                builder.append("%\n")
            }
            
            // Custom fields
            for (key, value) in session.metadata.customFields {
                builder.append(key)
                builder.append(": ")
                builder.append(value)
                builder.append("\n")
            }
        }
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