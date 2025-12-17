import XCTest
import PDFKit
@testable import VoiceFlow

final class PDFExporterTests: XCTestCase {

    var exporter: PDFExporter!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        exporter = PDFExporter()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        exporter = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testExportPDFWithDefaultConfiguration() throws {
        // Given
        let session = createTestSession(transcription: "Hello, this is a test transcription.")
        let outputURL = tempDirectory.appendingPathComponent("test.pdf")

        // When
        try exporter.exportToPDF(session: session, to: outputURL)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

        // Verify PDF can be loaded
        let document = PDFDocument(url: outputURL)
        XCTAssertNotNil(document, "PDF document should be loadable")
        XCTAssertGreaterThan(document?.pageCount ?? 0, 0, "PDF should have at least one page")
    }

    func testExportPDFWithCustomConfiguration() throws {
        // Given
        let session = createTestSession(transcription: "Custom configuration test")
        let outputURL = tempDirectory.appendingPathComponent("custom.pdf")

        let config = PDFExporter.PDFConfiguration(
            fontSize: 14,
            fontName: "Courier",
            lineSpacing: 2.0,
            margins: PDFExporter.PDFMargins(top: 100, bottom: 100, left: 100, right: 100),
            includeTimestamps: false,
            includeMetadata: false
        )

        // When
        try exporter.exportToPDF(session: session, to: outputURL, configuration: config)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let document = PDFDocument(url: outputURL)
        XCTAssertNotNil(document)
    }

    func testCreatePDFData() throws {
        // Given
        let session = createTestSession(transcription: "PDF data test")

        // When
        let data = try exporter.createPDFData(session: session)

        // Then
        XCTAssertFalse(data.isEmpty, "PDF data should not be empty")

        // Verify it's valid PDF data
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document, "Should create valid PDF document from data")
    }

    // MARK: - Metadata Tests

    func testPDFIncludesMetadata() throws {
        // Given
        let metadata = TranscriptionSession.Metadata(
            title: "Test Meeting",
            tags: ["important", "work"]
        )

        let session = createTestSession(
            transcription: "Meeting transcription",
            metadata: metadata
        )

        let config = PDFExporter.PDFConfiguration(includeMetadata: true)

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)
        let document = PDFDocument(data: data)

        // Then
        XCTAssertNotNil(document)

        let attributes = document?.documentAttributes
        XCTAssertNotNil(attributes)
    }

    func testPDFWithoutMetadata() throws {
        // Given
        let session = createTestSession(transcription: "No metadata test")
        let config = PDFExporter.PDFConfiguration(includeMetadata: false)

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)
        let document = PDFDocument(data: data)

        // Then
        XCTAssertNotNil(document)
        // Document should still be created, just without metadata in content
    }

    // MARK: - Timestamp Tests

    func testPDFWithTimestamps() throws {
        // Given
        let segments = [
            TranscriptionSegment(text: "First segment", startTime: 0, endTime: 5, confidence: 0.9),
            TranscriptionSegment(text: "Second segment", startTime: 5, endTime: 10, confidence: 0.85)
        ]

        let session = createTestSession(
            transcription: "First segment Second segment",
            segments: segments
        )

        let config = PDFExporter.PDFConfiguration(includeTimestamps: true)

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)

        // Then
        XCTAssertFalse(data.isEmpty)

        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    func testPDFWithoutTimestamps() throws {
        // Given
        let segments = [
            TranscriptionSegment(text: "Segment", startTime: 0, endTime: 5, confidence: 0.9)
        ]

        let session = createTestSession(
            transcription: "Segment",
            segments: segments
        )

        let config = PDFExporter.PDFConfiguration(includeTimestamps: false)

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    // MARK: - Pagination Tests

    func testPaginationForLongDocument() throws {
        // Given
        let longTranscription = String(repeating: "This is a long transcription. ", count: 500)
        let session = createTestSession(transcription: longTranscription)

        // When
        let data = try exporter.createPDFData(session: session)
        let document = PDFDocument(data: data)

        // Then
        XCTAssertNotNil(document)
        XCTAssertGreaterThan(document?.pageCount ?? 0, 1, "Long document should span multiple pages")
    }

    func testPaginationWithCustomPageSize() throws {
        // Given
        let longTranscription = String(repeating: "Content. ", count: 200)
        let session = createTestSession(transcription: longTranscription)

        let config = PDFExporter.PDFConfiguration(
            pageSize: CGSize(width: 595, height: 842) // A4
        )

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)
        let document = PDFDocument(data: data)

        // Then
        XCTAssertNotNil(document)
        XCTAssertGreaterThan(document?.pageCount ?? 0, 0)
    }

    // MARK: - Error Handling Tests

    func testEmptyContentError() {
        // Given
        let session = createTestSession(transcription: "")
        let outputURL = tempDirectory.appendingPathComponent("empty.pdf")

        // When/Then
        XCTAssertThrowsError(try exporter.exportToPDF(session: session, to: outputURL)) { error in
            XCTAssertEqual(error as? PDFExporter.PDFExportError, .emptyContent)
        }
    }

    func testInvalidFontError() {
        // Given
        let session = createTestSession(transcription: "Test")
        let config = PDFExporter.PDFConfiguration(fontName: "NonExistentFont123")

        // When/Then
        XCTAssertThrowsError(try exporter.createPDFData(session: session, configuration: config)) { error in
            XCTAssertEqual(error as? PDFExporter.PDFExportError, .fontNotFound)
        }
    }

    func testInvalidConfigurationError() {
        // Given
        let session = createTestSession(transcription: "Test")
        let config = PDFExporter.PDFConfiguration(
            fontSize: -1, // Invalid
            pageSize: CGSize(width: -100, height: -100) // Invalid
        )

        // When/Then
        XCTAssertThrowsError(try exporter.createPDFData(session: session, configuration: config)) { error in
            XCTAssertEqual(error as? PDFExporter.PDFExportError, .invalidConfiguration)
        }
    }

    // MARK: - Header and Footer Tests

    func testPDFWithCustomHeader() throws {
        // Given
        let session = createTestSession(transcription: "Header test")
        let config = PDFExporter.PDFConfiguration(
            includeHeader: true,
            headerText: "Custom Header Text"
        )

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    func testPDFWithCustomFooter() throws {
        // Given
        let session = createTestSession(transcription: "Footer test")
        let config = PDFExporter.PDFConfiguration(
            includeFooter: true,
            footerText: "Custom Footer - Page {page}"
        )

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    func testPDFWithoutHeaderAndFooter() throws {
        // Given
        let session = createTestSession(transcription: "No header/footer")
        let config = PDFExporter.PDFConfiguration(
            includeHeader: false,
            includeFooter: false
        )

        // When
        let data = try exporter.createPDFData(session: session, configuration: config)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    // MARK: - Edge Cases

    func testVeryShortContent() throws {
        // Given
        let session = createTestSession(transcription: "Hi")

        // When
        let data = try exporter.createPDFData(session: session)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.pageCount, 1)
    }

    func testSpecialCharactersInContent() throws {
        // Given
        let specialContent = "Special chars: @#$%^&*()[]{}|\\/<>?~`"
        let session = createTestSession(transcription: specialContent)

        // When
        let data = try exporter.createPDFData(session: session)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    func testUnicodeContent() throws {
        // Given
        let unicodeContent = "Unicode: 你好 مرحبا Здравствуйте 🎉"
        let session = createTestSession(transcription: unicodeContent)

        // When
        let data = try exporter.createPDFData(session: session)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    func testMultipleLanguages() throws {
        // Given
        let session = createTestSession(
            transcription: "Test in English",
            language: .english
        )

        // When
        let data = try exporter.createPDFData(session: session)

        // Then
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
    }

    // MARK: - Helper Methods

    private func createTestSession(
        transcription: String,
        segments: [TranscriptionSegment] = [],
        metadata: TranscriptionSession.Metadata = TranscriptionSession.Metadata(),
        language: Language = .english
    ) -> TranscriptionSession {
        TranscriptionSession(
            id: UUID(),
            startTime: Date(),
            endTime: Date(),
            duration: 60.0,
            wordCount: transcription.split(separator: " ").count,
            averageConfidence: 0.95,
            context: "general",
            transcription: transcription,
            segments: segments,
            metadata: metadata,
            createdAt: Date(),
            language: language
        )
    }
}

// MARK: - PDFExportError Equatable

extension PDFExporter.PDFExportError: Equatable {
    public static func == (lhs: PDFExporter.PDFExportError, rhs: PDFExporter.PDFExportError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidConfiguration, .invalidConfiguration),
             (.emptyContent, .emptyContent),
             (.fontNotFound, .fontNotFound),
             (.pageCreationFailed, .pageCreationFailed),
             (.documentCreationFailed, .documentCreationFailed):
            return true
        case (.fileWriteFailed(let lhsURL), .fileWriteFailed(let rhsURL)):
            return lhsURL == rhsURL
        default:
            return false
        }
    }
}
