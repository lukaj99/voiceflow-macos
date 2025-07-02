import Foundation

/// Service responsible for exporting transcriptions in various formats following Single Responsibility Principle
public final class TranscriptionExportService {
    
    // MARK: - Export Formats
    
    public enum ExportFormat: String, CaseIterable {
        case plainText = "txt"
        case markdown = "md"
        case json = "json"
        case csv = "csv"
        case xml = "xml"
        
        public var displayName: String {
            switch self {
            case .plainText: return "Plain Text"
            case .markdown: return "Markdown"
            case .json: return "JSON"
            case .csv: return "CSV"
            case .xml: return "XML"
            }
        }
        
        public var fileExtension: String {
            return rawValue
        }
    }
    
    // MARK: - Public Methods
    
    public func exportTranscription(
        _ session: TranscriptionSession,
        format: ExportFormat,
        includeMetadata: Bool = true,
        includeTimestamps: Bool = false
    ) -> String {
        switch format {
        case .plainText:
            return exportAsPlainText(session, includeMetadata: includeMetadata)
        case .markdown:
            return exportAsMarkdown(session, includeMetadata: includeMetadata, includeTimestamps: includeTimestamps)
        case .json:
            return exportAsJSON(session, includeTimestamps: includeTimestamps)
        case .csv:
            return exportAsCSV(session, includeTimestamps: includeTimestamps)
        case .xml:
            return exportAsXML(session, includeTimestamps: includeTimestamps)
        }
    }
    
    public func exportTranscriptionData(
        _ session: TranscriptionSession,
        format: ExportFormat,
        includeMetadata: Bool = true,
        includeTimestamps: Bool = false
    ) -> Data {
        let content = exportTranscription(
            session,
            format: format,
            includeMetadata: includeMetadata,
            includeTimestamps: includeTimestamps
        )
        
        return content.data(using: .utf8) ?? Data()
    }
    
    // MARK: - Private Export Methods
    
    private func exportAsPlainText(_ session: TranscriptionSession, includeMetadata: Bool) -> String {
        var content = ""
        
        if includeMetadata && session.metadata != nil {
            content += generateMetadataHeader(session)
            content += "\n---\n\n"
        }
        
        content += session.transcription
        
        return content
    }
    
    private func exportAsMarkdown(_ session: TranscriptionSession, includeMetadata: Bool, includeTimestamps: Bool) -> String {
        var content = "# Transcription Session\n\n"
        
        if includeMetadata {
            content += generateMarkdownMetadata(session)
            content += "\n---\n\n"
        }
        
        content += "## Transcript\n\n"
        
        if includeTimestamps && !session.wordTimings.isEmpty {
            content += generateTimestampedMarkdown(session)
        } else {
            content += session.transcription
        }
        
        return content
    }
    
    private func exportAsJSON(_ session: TranscriptionSession, includeTimestamps: Bool) -> String {
        var exportData: [String: Any] = [
            "id": session.id.uuidString,
            "transcription": session.transcription,
            "startTime": session.startTime.iso8601String,
            "duration": session.duration,
            "wordCount": session.wordCount,
            "averageConfidence": session.averageConfidence
        ]
        
        if let endTime = session.endTime {
            exportData["endTime"] = endTime.iso8601String
        }
        
        if let metadata = session.metadata {
            exportData["metadata"] = [
                "language": metadata.language,
                "context": metadata.context?.description ?? "general",
                "deviceInfo": metadata.deviceInfo
            ]
        }
        
        if includeTimestamps && !session.wordTimings.isEmpty {
            exportData["wordTimings"] = session.wordTimings.map { timing in
                [
                    "word": timing.word,
                    "startTime": timing.startTime,
                    "endTime": timing.endTime,
                    "confidence": timing.confidence
                ]
            }
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize JSON: \\(error.localizedDescription)\"}"
        }
    }
    
    private func exportAsCSV(_ session: TranscriptionSession, includeTimestamps: Bool) -> String {
        var csv = ""
        
        // Add session header
        csv += "Session ID,Start Time,End Time,Duration,Word Count,Average Confidence,Transcription\n"
        csv += "\"\(session.id.uuidString)\","
        csv += "\"\(session.startTime.iso8601String)\","
        csv += "\"\(session.endTime?.iso8601String ?? "")\","
        csv += "\(session.duration),"
        csv += "\(session.wordCount),"
        csv += "\(session.averageConfidence),"
        csv += "\"\(session.transcription.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
        
        // Add word timings if requested
        if includeTimestamps && !session.wordTimings.isEmpty {
            csv += "\nWord,Start Time,End Time,Confidence\n"
            for timing in session.wordTimings {
                csv += "\"\(timing.word.replacingOccurrences(of: "\"", with: "\"\""))\","
                csv += "\(timing.startTime),"
                csv += "\(timing.endTime),"
                csv += "\(timing.confidence)\n"
            }
        }
        
        return csv
    }
    
    private func exportAsXML(_ session: TranscriptionSession, includeTimestamps: Bool) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<transcriptionSession>\n"
        xml += "  <id>\(session.id.uuidString)</id>\n"
        xml += "  <startTime>\(session.startTime.iso8601String)</startTime>\n"
        
        if let endTime = session.endTime {
            xml += "  <endTime>\(endTime.iso8601String)</endTime>\n"
        }
        
        xml += "  <duration>\(session.duration)</duration>\n"
        xml += "  <wordCount>\(session.wordCount)</wordCount>\n"
        xml += "  <averageConfidence>\(session.averageConfidence)</averageConfidence>\n"
        
        if let metadata = session.metadata {
            xml += "  <metadata>\n"
            xml += "    <language>\(metadata.language)</language>\n"
            xml += "    <context>\(metadata.context?.description ?? "general")</context>\n"
            xml += "    <deviceInfo>\(metadata.deviceInfo)</deviceInfo>\n"
            xml += "  </metadata>\n"
        }
        
        xml += "  <transcription><![CDATA[\(session.transcription)]]></transcription>\n"
        
        if includeTimestamps && !session.wordTimings.isEmpty {
            xml += "  <wordTimings>\n"
            for timing in session.wordTimings {
                xml += "    <word>\n"
                xml += "      <text>\(timing.word)</text>\n"
                xml += "      <startTime>\(timing.startTime)</startTime>\n"
                xml += "      <endTime>\(timing.endTime)</endTime>\n"
                xml += "      <confidence>\(timing.confidence)</confidence>\n"
                xml += "    </word>\n"
            }
            xml += "  </wordTimings>\n"
        }
        
        xml += "</transcriptionSession>\n"
        return xml
    }
    
    // MARK: - Helper Methods
    
    private func generateMetadataHeader(_ session: TranscriptionSession) -> String {
        var metadata = "Transcription Session\n"
        metadata += "Date: \(session.startTime.formatted())\n"
        metadata += "Duration: \(formatDuration(session.duration))\n"
        metadata += "Words: \(session.wordCount)\n"
        metadata += "Average Confidence: \(Int(session.averageConfidence * 100))%\n"
        
        if let sessionMetadata = session.metadata {
            metadata += "Language: \(sessionMetadata.language)\n"
            if let context = sessionMetadata.context {
                metadata += "Context: \(context.description)\n"
            }
        }
        
        return metadata
    }
    
    private func generateMarkdownMetadata(_ session: TranscriptionSession) -> String {
        var metadata = "**Date**: \(session.startTime.formatted())  \n"
        metadata += "**Duration**: \(formatDuration(session.duration))  \n"
        metadata += "**Words**: \(session.wordCount)  \n"
        metadata += "**Average Confidence**: \(Int(session.averageConfidence * 100))%  \n"
        
        if let sessionMetadata = session.metadata {
            metadata += "**Language**: \(sessionMetadata.language)  \n"
            if let context = sessionMetadata.context {
                metadata += "**Context**: \(context.description)  \n"
            }
        }
        
        return metadata
    }
    
    private func generateTimestampedMarkdown(_ session: TranscriptionSession) -> String {
        var content = ""
        
        for timing in session.wordTimings {
            let timestamp = formatTimestamp(timing.startTime)
            content += "`[\(timestamp)]` \(timing.word) "
        }
        
        return content
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}