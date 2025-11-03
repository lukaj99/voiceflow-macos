import XCTest
@testable import VoiceFlow

/// Comprehensive test suite for DOCXExporter
/// Validates DOCX generation, formatting, and error handling
final class DOCXExporterTests: XCTestCase {

    var exporter: DOCXExporter!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        exporter = DOCXExporter()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DOCXExporterTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        exporter = nil
        super.tearDown()
    }

    // MARK: - Basic Export Tests

    func testExportWithDefaultOptions() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("test.docx")
        let config = ExportConfiguration()

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0, "DOCX file should not be empty")

        // Verify it's a valid ZIP file (DOCX is ZIP format)
        try verifyDOCXStructure(at: outputURL)
    }

    func testExportWithCustomFormatting() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("custom.docx")
        let config = ExportConfiguration()
        let options = DOCXExporter.FormattingOptions(
            fontName: "Arial",
            fontSize: 12,
            lineSpacing: 1.5,
            headerEnabled: true,
            footerEnabled: true,
            boldTitle: true,
            italicMetadata: true
        )

        // When
        try exporter.export(session: session, to: outputURL, configuration: config, options: options)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try verifyDOCXStructure(at: outputURL)

        // Verify content includes formatting
        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("<w:b/>"), "Should contain bold formatting")
        XCTAssertTrue(content.contains("<w:i/>"), "Should contain italic formatting")
    }

    func testExportWithMetadata() throws {
        // Given
        let session = createTestSession(withMetadata: true)
        let outputURL = tempDirectory.appendingPathComponent("with-metadata.docx")
        let config = ExportConfiguration(includeTimestamps: true, includeMetadata: true)

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("VoiceFlow Transcription"), "Should contain title")
        XCTAssertTrue(content.contains("Date:"), "Should contain date metadata")
        XCTAssertTrue(content.contains("Duration:"), "Should contain duration")
        XCTAssertTrue(content.contains("Words:"), "Should contain word count")
        XCTAssertTrue(content.contains("Confidence:"), "Should contain confidence")
    }

    func testExportWithoutMetadata() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("no-metadata.docx")
        let config = ExportConfiguration(includeTimestamps: false, includeMetadata: false)

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("Test transcription content"))
        XCTAssertFalse(content.contains("Date:"))
    }

    // MARK: - Header and Footer Tests

    func testExportWithHeader() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("with-header.docx")
        let config = ExportConfiguration()
        let options = DOCXExporter.FormattingOptions(headerEnabled: true, footerEnabled: false)

        // When
        try exporter.export(session: session, to: outputURL, configuration: config, options: options)

        // Then
        try verifyDOCXHasHeader(at: outputURL)
    }

    func testExportWithFooter() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("with-footer.docx")
        let config = ExportConfiguration()
        let options = DOCXExporter.FormattingOptions(headerEnabled: false, footerEnabled: true)

        // When
        try exporter.export(session: session, to: outputURL, configuration: config, options: options)

        // Then
        try verifyDOCXHasFooter(at: outputURL)
    }

    func testExportWithBothHeaderAndFooter() throws {
        // Given
        let session = createTestSession()
        let outputURL = tempDirectory.appendingPathComponent("header-footer.docx")
        let config = ExportConfiguration()
        let options = DOCXExporter.FormattingOptions(headerEnabled: true, footerEnabled: true)

        // When
        try exporter.export(session: session, to: outputURL, configuration: config, options: options)

        // Then
        try verifyDOCXHasHeader(at: outputURL)
        try verifyDOCXHasFooter(at: outputURL)
    }

    // MARK: - Content Tests

    func testExportWithLongContent() throws {
        // Given
        let longText = String(repeating: "This is a long transcription. ", count: 1000)
        let session = createTestSession(transcription: longText)
        let outputURL = tempDirectory.appendingPathComponent("long-content.docx")
        let config = ExportConfiguration()

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("long transcription"))

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 5000, "Long document should be larger")
    }

    func testExportWithMultilineContent() throws {
        // Given
        let multilineText = """
        First line of transcription
        Second line with more content
        Third line with even more
        Fourth line final
        """
        let session = createTestSession(transcription: multilineText)
        let outputURL = tempDirectory.appendingPathComponent("multiline.docx")
        let config = ExportConfiguration()

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("First line"))
        XCTAssertTrue(content.contains("Second line"))
        XCTAssertTrue(content.contains("Third line"))
        XCTAssertTrue(content.contains("Fourth line"))
    }

    func testExportWithSpecialCharacters() throws {
        // Given
        let specialText = "Test with <special> & \"characters\" and 'quotes'"
        let session = createTestSession(transcription: specialText)
        let outputURL = tempDirectory.appendingPathComponent("special-chars.docx")
        let config = ExportConfiguration()

        // When
        try exporter.export(session: session, to: outputURL, configuration: config)

        // Then
        let content = try extractDOCXContent(from: outputURL)
        // XML should escape special characters
        XCTAssertTrue(content.contains("&lt;special&gt;"))
        XCTAssertTrue(content.contains("&amp;"))
        XCTAssertTrue(content.contains("&quot;"))
    }

    // MARK: - Error Handling Tests

    func testExportWithEmptyTranscription() {
        // Given
        let session = createTestSession(transcription: "")
        let outputURL = tempDirectory.appendingPathComponent("empty.docx")
        let config = ExportConfiguration()

        // When/Then
        XCTAssertThrowsError(try exporter.export(session: session, to: outputURL, configuration: config)) { error in
            XCTAssertTrue(error is DOCXExporter.DOCXError)
            XCTAssertEqual(error as? DOCXExporter.DOCXError, .invalidSession)
        }
    }

    func testExportToInvalidPath() {
        // Given
        let session = createTestSession()
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.docx")
        let config = ExportConfiguration()

        // When/Then
        XCTAssertThrowsError(try exporter.export(session: session, to: invalidURL, configuration: config))
    }

    // MARK: - Formatting Options Tests

    func testFormattingOptionsDefaults() {
        // Given/When
        let options = DOCXExporter.FormattingOptions.default

        // Then
        XCTAssertEqual(options.fontName, "Calibri")
        XCTAssertEqual(options.fontSize, 11)
        XCTAssertEqual(options.lineSpacing, 1.15)
        XCTAssertTrue(options.headerEnabled)
        XCTAssertTrue(options.footerEnabled)
        XCTAssertTrue(options.boldTitle)
        XCTAssertFalse(options.italicMetadata)
    }

    func testFormattingOptionsCustomValues() {
        // Given/When
        let options = DOCXExporter.FormattingOptions(
            fontName: "Times New Roman",
            fontSize: 14,
            lineSpacing: 2.0,
            headerEnabled: false,
            footerEnabled: false,
            boldTitle: false,
            italicMetadata: true
        )

        // Then
        XCTAssertEqual(options.fontName, "Times New Roman")
        XCTAssertEqual(options.fontSize, 14)
        XCTAssertEqual(options.lineSpacing, 2.0)
        XCTAssertFalse(options.headerEnabled)
        XCTAssertFalse(options.footerEnabled)
        XCTAssertFalse(options.boldTitle)
        XCTAssertTrue(options.italicMetadata)
    }

    // MARK: - Integration Tests

    func testMultipleExportsToSameLocation() throws {
        // Given
        let session1 = createTestSession(transcription: "First export")
        let session2 = createTestSession(transcription: "Second export")
        let outputURL = tempDirectory.appendingPathComponent("overwrite.docx")
        let config = ExportConfiguration()

        // When
        try exporter.export(session: session1, to: outputURL, configuration: config)
        let firstAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let firstSize = firstAttributes[.size] as? Int ?? 0

        try exporter.export(session: session2, to: outputURL, configuration: config)
        let secondAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let secondSize = secondAttributes[.size] as? Int ?? 0

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let content = try extractDOCXContent(from: outputURL)
        XCTAssertTrue(content.contains("Second export"))
        XCTAssertFalse(content.contains("First export"))

        // Sizes might differ but both should be valid
        XCTAssertGreaterThan(firstSize, 0)
        XCTAssertGreaterThan(secondSize, 0)
    }

    func testConcurrentExports() throws {
        // Given
        let session = createTestSession()
        let config = ExportConfiguration()
        let expectation = self.expectation(description: "Concurrent exports")
        expectation.expectedFulfillmentCount = 3

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        var errors: [Error] = []
        let errorQueue = DispatchQueue(label: "test.errors")

        // When
        for i in 1...3 {
            queue.async {
                do {
                    let url = self.tempDirectory.appendingPathComponent("concurrent-\(i).docx")
                    try self.exporter.export(session: session, to: url, configuration: config)
                    expectation.fulfill()
                } catch {
                    errorQueue.sync {
                        errors.append(error)
                    }
                    expectation.fulfill()
                }
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(errors.isEmpty, "Should not have errors: \(errors)")

        // Verify all files created
        for i in 1...3 {
            let url = tempDirectory.appendingPathComponent("concurrent-\(i).docx")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - Helper Methods

    private func createTestSession(
        transcription: String = "Test transcription content",
        withMetadata: Bool = false
    ) -> TranscriptionSession {
        let metadata = TranscriptionSession.Metadata(
            appName: withMetadata ? "TestApp" : nil,
            title: withMetadata ? "Test Session" : nil,
            tags: withMetadata ? ["test", "export"] : []
        )

        return TranscriptionSession(
            id: UUID(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            duration: 60,
            wordCount: transcription.components(separatedBy: .whitespaces).count,
            averageConfidence: 0.95,
            context: "general",
            transcription: transcription,
            segments: [],
            metadata: metadata,
            createdAt: Date(),
            language: .english
        )
    }

    private func verifyDOCXStructure(at url: URL) throws {
        // Unzip and verify DOCX structure
        let unzipDir = tempDirectory.appendingPathComponent("unzipped-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", unzipDir.path]
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, "Should successfully unzip DOCX")

        // Verify key files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: unzipDir.appendingPathComponent("[Content_Types].xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unzipDir.appendingPathComponent("_rels/.rels").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unzipDir.appendingPathComponent("word/document.xml").path))

        try? FileManager.default.removeItem(at: unzipDir)
    }

    private func extractDOCXContent(from url: URL) throws -> String {
        let unzipDir = tempDirectory.appendingPathComponent("extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: unzipDir)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", unzipDir.path]
        try process.run()
        process.waitUntilExit()

        let documentURL = unzipDir.appendingPathComponent("word/document.xml")
        return try String(contentsOf: documentURL, encoding: .utf8)
    }

    private func verifyDOCXHasHeader(at url: URL) throws {
        let unzipDir = tempDirectory.appendingPathComponent("header-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: unzipDir)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", unzipDir.path]
        try process.run()
        process.waitUntilExit()

        let headerURL = unzipDir.appendingPathComponent("word/header1.xml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: headerURL.path), "Header file should exist")

        let headerContent = try String(contentsOf: headerURL, encoding: .utf8)
        XCTAssertTrue(headerContent.contains("VoiceFlow"), "Header should contain app name")
    }

    private func verifyDOCXHasFooter(at url: URL) throws {
        let unzipDir = tempDirectory.appendingPathComponent("footer-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: unzipDir)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", unzipDir.path]
        try process.run()
        process.waitUntilExit()

        let footerURL = unzipDir.appendingPathComponent("word/footer1.xml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: footerURL.path), "Footer file should exist")

        let footerContent = try String(contentsOf: footerURL, encoding: .utf8)
        XCTAssertTrue(footerContent.contains("Session ID"), "Footer should contain session ID")
    }
}
