//
//  MockExportService.swift
//  VoiceFlowTests
//
//  Mock implementation of export services for testing
//

import Foundation
@testable import VoiceFlow

/// Mock export service for testing export functionality
public final actor MockExportService: Sendable {
    
    // MARK: - Properties
    
    /// Exported files tracking
    private var exportedFiles: [ExportRecord] = []
    
    /// Export format support
    private var supportedFormats: Set<ExportFormat> = [.text, .markdown, .pdf, .docx, .srt]
    
    /// Error to throw on next export
    private var nextError: Error?
    
    /// Export delay simulation
    private var exportDelay: TimeInterval = 0.1
    
    /// Export success rate (0.0 - 1.0)
    private var successRate: Double = 1.0
    
    // MARK: - Types
    
    public struct ExportRecord: Sendable {
        public let id: UUID
        public let format: ExportFormat
        public let content: Data
        public let metadata: ExportMetadata
        public let timestamp: Date
        public let destination: URL
    }
    
    public enum MockError: LocalizedError, Sendable {
        case unsupportedFormat(ExportFormat)
        case exportFailed(String)
        case invalidData
        case diskFull
        case permissionDenied
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format):
                return "Unsupported export format: \(format)"
            case .exportFailed(let reason):
                return "Export failed: \(reason)"
            case .invalidData:
                return "Invalid export data"
            case .diskFull:
                return "Insufficient disk space"
            case .permissionDenied:
                return "Permission denied for export"
            }
        }
    }
    
    // MARK: - Configuration
    
    public func setSupportedFormats(_ formats: Set<ExportFormat>) {
        self.supportedFormats = formats
    }
    
    public func setNextError(_ error: Error?) {
        self.nextError = error
    }
    
    public func setExportDelay(_ delay: TimeInterval) {
        self.exportDelay = max(0, delay)
    }
    
    public func setSuccessRate(_ rate: Double) {
        self.successRate = max(0, min(1, rate))
    }
    
    // MARK: - Export Methods
    
    public func export(
        data: ExportData,
        format: ExportFormat,
        to destination: URL
    ) async throws -> ExportRecord {
        // Simulate export delay
        if exportDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(exportDelay * 1_000_000_000))
        }
        
        // Check for configured error
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        // Check success rate
        if Double.random(in: 0...1) > successRate {
            throw MockError.exportFailed("Random failure for testing")
        }
        
        // Check format support
        guard supportedFormats.contains(format) else {
            throw MockError.unsupportedFormat(format)
        }
        
        // Generate mock export content
        let content = try generateMockContent(for: data, format: format)
        
        // Create export record
        let record = ExportRecord(
            id: UUID(),
            format: format,
            content: content,
            metadata: data.metadata,
            timestamp: Date(),
            destination: destination
        )
        
        exportedFiles.append(record)
        
        return record
    }
    
    public func batchExport(
        data: ExportData,
        formats: [ExportFormat],
        to directory: URL
    ) async throws -> [ExportRecord] {
        var records: [ExportRecord] = []
        
        for format in formats {
            let filename = "export_\(UUID().uuidString).\(format.fileExtension)"
            let destination = directory.appendingPathComponent(filename)
            
            do {
                let record = try await export(
                    data: data,
                    format: format,
                    to: destination
                )
                records.append(record)
            } catch {
                // Continue with other formats on error
                print("Failed to export \(format): \(error)")
            }
        }
        
        return records
    }
    
    // MARK: - Content Generation
    
    private func generateMockContent(
        for data: ExportData,
        format: ExportFormat
    ) throws -> Data {
        switch format {
        case .text:
            return generateTextContent(data)
        case .markdown:
            return generateMarkdownContent(data)
        case .pdf:
            return generatePDFContent(data)
        case .docx:
            return generateDocxContent(data)
        case .srt:
            return generateSRTContent(data)
        }
    }
    
    private func generateTextContent(_ data: ExportData) -> Data {
        let content = """
        Transcription
        =============
        
        \(data.transcription)
        
        ---
        Duration: \(data.metadata.duration)s
        Words: \(data.metadata.wordCount)
        Created: \(data.metadata.createdAt)
        """
        
        return content.data(using: .utf8) ?? Data()
    }
    
    private func generateMarkdownContent(_ data: ExportData) -> Data {
        let content = """
        # Transcription
        
        **Date**: \(data.metadata.createdAt)  
        **Duration**: \(data.metadata.duration) seconds  
        **Words**: \(data.metadata.wordCount)
        
        ## Content
        
        \(data.transcription)
        
        ## Segments
        
        \(data.segments.map { "- [\($0.startTime)s - \($0.endTime)s]: \($0.text)" }.joined(separator: "\n"))
        """
        
        return content.data(using: .utf8) ?? Data()
    }
    
    private func generatePDFContent(_ data: ExportData) -> Data {
        // Mock PDF header
        let pdfHeader = "%PDF-1.4\n"
        let content = pdfHeader + "Mock PDF content for: \(data.transcription.prefix(50))..."
        return content.data(using: .utf8) ?? Data()
    }
    
    private func generateDocxContent(_ data: ExportData) -> Data {
        // Mock DOCX header (ZIP format)
        let docxHeader = "PK\u{03}\u{04}"
        let content = docxHeader + "Mock DOCX content for: \(data.transcription.prefix(50))..."
        return content.data(using: .utf8) ?? Data()
    }
    
    private func generateSRTContent(_ data: ExportData) -> Data {
        var srtContent = ""
        
        for (index, segment) in data.segments.enumerated() {
            srtContent += """
            \(index + 1)
            \(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))
            \(segment.text)
            
            
            """
        }
        
        return srtContent.data(using: .utf8) ?? Data()
    }
    
    private func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    // MARK: - Query Methods
    
    public func getExportedFiles() -> [ExportRecord] {
        return exportedFiles
    }
    
    public func getExportCount() -> Int {
        return exportedFiles.count
    }
    
    public func getExportsByFormat(_ format: ExportFormat) -> [ExportRecord] {
        return exportedFiles.filter { $0.format == format }
    }
    
    public func clearExportHistory() {
        exportedFiles.removeAll()
    }
    
    public func getTotalExportSize() -> Int {
        return exportedFiles.reduce(0) { $0 + $1.content.count }
    }
}

// MARK: - Export Format Extensions

extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .markdown: return "md"
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .srt: return "srt"
        }
    }
}

// MARK: - Test Factory

public struct MockExportServiceFactory {
    
    public static func createDefaultService() -> MockExportService {
        let service = MockExportService()
        return service
    }
    
    public static func createFastService() async -> MockExportService {
        let service = createDefaultService()
        await service.setExportDelay(0.001)
        return service
    }
    
    public static func createUnreliableService() async -> MockExportService {
        let service = createDefaultService()
        await service.setSuccessRate(0.5)
        return service
    }
    
    public static func createLimitedService() async -> MockExportService {
        let service = createDefaultService()
        await service.setSupportedFormats([.text, .markdown])
        return service
    }
}