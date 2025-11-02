import XCTest
import Foundation
@testable import VoiceFlow

/// Comprehensive tests for ExportManager functionality
@MainActor
final class ExportManagerTests: XCTestCase {

    private var exportManager: ExportManager!
    private var testSession: TranscriptionSession!
    private var tempDirectory: URL!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        exportManager = ExportManager()

        // Create test session with realistic data
        testSession = TranscriptionSession(
            startTime: Date(),
            endTime: Date().addingTimeInterval(120),
            duration: 120,
            wordCount: 25,
            averageConfidence: 0.95,
            context: "general",
            transcription: "This is a test transcription with multiple words.",
            segments: [
                TranscriptionSegment(text: "This is a test", startTime: 0, endTime: 2.5, confidence: 0.95),
                TranscriptionSegment(text: "transcription with", startTime: 2.5, endTime: 5.0, confidence: 0.97),
                TranscriptionSegment(text: "multiple words.", startTime: 5.0, endTime: 7.0, confidence: 0.93)
            ],
            language: .english
        )

        // Create temporary directory for test exports
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceFlowTestExports")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    @MainActor
    override func tearDown() async throws {
        exportManager = nil
        testSession = nil

        // Clean up temporary files
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testExportManagerInitialization() async {
        // Then
        XCTAssertNotNil(exportManager)
    }

    // MARK: - Text Export Tests

    func testExportToTextFormat() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        let config = ExportConfiguration(includeTimestamps: false, includeMetadata: true)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.filePath, fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("VoiceFlow Transcription"))
        XCTAssertTrue(content.contains(testSession.transcription))
    }

    func testExportToTextWithoutMetadata() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test_no_metadata.txt")
        let config = ExportConfiguration(includeTimestamps: false, includeMetadata: false)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertFalse(content.contains("VoiceFlow Transcription"))
        XCTAssertTrue(content.contains(testSession.transcription))
        XCTAssertEqual(content.trimmingCharacters(in: .whitespacesAndNewlines), testSession.transcription)
    }

    func testTextExportContainsMetadata() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test_metadata.txt")
        let config = ExportConfiguration(includeMetadata: true)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("Duration:"))
        XCTAssertTrue(content.contains("Words: \(testSession.wordCount)"))
        XCTAssertTrue(content.contains("Confidence:"))
    }

    // MARK: - Markdown Export Tests

    func testExportToMarkdownFormat() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test.md")
        let config = ExportConfiguration(includeMetadata: true)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .markdown,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.filePath, fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("# VoiceFlow Transcription"))
        XCTAssertTrue(content.contains("## Transcript"))
        XCTAssertTrue(content.contains(testSession.transcription))
    }

    func testMarkdownExportFormattingWithMetadata() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test_formatted.md")
        let config = ExportConfiguration(includeMetadata: true)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .markdown,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("**Date**:"))
        XCTAssertTrue(content.contains("**Duration**:"))
        XCTAssertTrue(content.contains("**Words**:"))
        XCTAssertTrue(content.contains("**Confidence**:"))
        XCTAssertTrue(content.contains("---"))
    }

    func testMarkdownExportWithoutMetadata() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("test_no_meta.md")
        let config = ExportConfiguration(includeMetadata: false)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .markdown,
            to: fileURL,
            configuration: config
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("# VoiceFlow Transcription"))
        XCTAssertFalse(content.contains("**Date**:"))
        XCTAssertTrue(content.contains("## Transcript"))
    }

    // MARK: - Export Result Tests

    func testExportResultMetadata() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("result_test.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.metadata["format"])
        XCTAssertNotNil(result.metadata["size"])
        XCTAssertNotNil(result.metadata["timestamp"])
        XCTAssertEqual(result.metadata["format"] as? String, "txt")
    }

    func testExportResultContainsFileSize() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("size_test.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        let size = result.metadata["size"] as? Int
        XCTAssertNotNil(size)
        XCTAssertGreaterThan(size ?? 0, 0)
    }

    // MARK: - Format Tests

    func testAllExportFormats() throws {
        // Test all supported formats
        let formats: [ExportFormat] = [.text, .markdown, .pdf, .docx, .srt]

        for format in formats {
            // Given
            let fileURL = tempDirectory.appendingPathComponent("test.\(format.fileExtension)")

            // When
            let result = try exportManager.exportTranscription(
                session: testSession,
                format: format,
                to: fileURL
            )

            // Then
            XCTAssertTrue(result.success, "Export failed for format: \(format.displayName)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "File not created for: \(format.displayName)")
        }
    }

    func testExportFormatDisplayNames() {
        // Then
        XCTAssertEqual(ExportFormat.text.displayName, "Text")
        XCTAssertEqual(ExportFormat.markdown.displayName, "Markdown")
        XCTAssertEqual(ExportFormat.pdf.displayName, "PDF")
        XCTAssertEqual(ExportFormat.docx.displayName, "DOCX")
        XCTAssertEqual(ExportFormat.srt.displayName, "SRT")
    }

    func testExportFormatFileExtensions() {
        // Then
        XCTAssertEqual(ExportFormat.text.fileExtension, "txt")
        XCTAssertEqual(ExportFormat.markdown.fileExtension, "md")
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.docx.fileExtension, "docx")
        XCTAssertEqual(ExportFormat.srt.fileExtension, "srt")
    }

    // MARK: - Edge Case Tests

    func testExportEmptyTranscription() throws {
        // Given
        let emptySession = TranscriptionSession(
            duration: 0,
            wordCount: 0,
            averageConfidence: 0,
            transcription: ""
        )
        let fileURL = tempDirectory.appendingPathComponent("empty.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: emptySession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testExportLargeTranscription() throws {
        // Given
        let largeText = String(repeating: "This is a large transcription. ", count: 1000)
        let largeSession = TranscriptionSession(
            duration: 3600,
            wordCount: 5000,
            averageConfidence: 0.92,
            transcription: largeText
        )
        let fileURL = tempDirectory.appendingPathComponent("large.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: largeSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains(largeText))
    }

    func testExportWithSpecialCharacters() throws {
        // Given
        let specialSession = TranscriptionSession(
            transcription: "Special chars: !@#$%^&*(){}[]|\\:;\"'<>,.?/~`"
        )
        let fileURL = tempDirectory.appendingPathComponent("special.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: specialSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("Special chars:"))
    }

    func testExportWithUnicodeCharacters() throws {
        // Given
        let unicodeSession = TranscriptionSession(
            transcription: "Unicode: 你好世界 🎉 émojis café naïve"
        )
        let fileURL = tempDirectory.appendingPathComponent("unicode.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: unicodeSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("你好世界") ?? false)
        XCTAssertTrue(content?.contains("🎉") ?? false)
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() throws {
        // Given
        let defaultConfig = ExportConfiguration()
        let fileURL = tempDirectory.appendingPathComponent("default_config.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL,
            configuration: defaultConfig
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(defaultConfig.includeTimestamps)
        XCTAssertTrue(defaultConfig.includeMetadata)
    }

    func testCustomConfiguration() throws {
        // Given
        let customConfig = ExportConfiguration(includeTimestamps: false, includeMetadata: false)
        let fileURL = tempDirectory.appendingPathComponent("custom_config.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL,
            configuration: customConfig
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertFalse(customConfig.includeTimestamps)
        XCTAssertFalse(customConfig.includeMetadata)
    }

    // MARK: - File System Tests

    func testExportOverwritesExistingFile() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("overwrite.txt")
        try "Old content".write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: fileURL
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertFalse(content.contains("Old content"))
        XCTAssertTrue(content.contains(testSession.transcription))
    }

    func testExportCreatesIntermediateDirectories() throws {
        // Given
        let nestedURL = tempDirectory
            .appendingPathComponent("level1")
            .appendingPathComponent("level2")
            .appendingPathComponent("test.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: testSession,
            format: .text,
            to: nestedURL
        )

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
    }

    // MARK: - Duration Formatting Tests

    func testDurationFormattingShort() throws {
        // Given
        let shortSession = TranscriptionSession(duration: 45)
        let fileURL = tempDirectory.appendingPathComponent("duration_short.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: shortSession,
            format: .text,
            to: fileURL,
            configuration: ExportConfiguration(includeMetadata: true)
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("Duration:"))
    }

    func testDurationFormattingLong() throws {
        // Given
        let longSession = TranscriptionSession(duration: 3665) // 1h 1m 5s
        let fileURL = tempDirectory.appendingPathComponent("duration_long.txt")

        // When
        let result = try exportManager.exportTranscription(
            session: longSession,
            format: .text,
            to: fileURL,
            configuration: ExportConfiguration(includeMetadata: true)
        )

        // Then
        XCTAssertTrue(result.success)
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("Duration:"))
    }

    // MARK: - Performance Tests

    func testExportPerformance() throws {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("performance.txt")

        // When/Then
        measure {
            do {
                _ = try exportManager.exportTranscription(
                    session: testSession,
                    format: .text,
                    to: fileURL
                )
            } catch {
                XCTFail("Export failed: \(error)")
            }
        }
    }

    func testMultipleExportsPerformance() throws {
        // When/Then
        measure {
            for i in 0..<10 {
                let fileURL = tempDirectory.appendingPathComponent("perf_\(i).txt")
                do {
                    _ = try exportManager.exportTranscription(
                        session: testSession,
                        format: .text,
                        to: fileURL
                    )
                } catch {
                    XCTFail("Export \(i) failed: \(error)")
                }
            }
        }
    }
}
