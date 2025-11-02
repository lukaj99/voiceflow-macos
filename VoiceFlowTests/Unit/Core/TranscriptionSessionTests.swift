import XCTest
@testable import VoiceFlow

/// Comprehensive tests for TranscriptionSession model
final class TranscriptionSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testTranscriptionSessionDefaultInitialization() {
        // When
        let session = TranscriptionSession()

        // Then
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.duration, 0)
        XCTAssertEqual(session.wordCount, 0)
        XCTAssertEqual(session.averageConfidence, 0)
        XCTAssertEqual(session.context, "general")
        XCTAssertEqual(session.transcription, "")
        XCTAssertTrue(session.segments.isEmpty)
        XCTAssertEqual(session.language, .english)
    }

    func testTranscriptionSessionCustomInitialization() {
        // Given
        let id = UUID()
        let startTime = Date()
        let endTime = Date().addingTimeInterval(60)
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0, endTime: 1, confidence: 0.9),
            TranscriptionSegment(text: "World", startTime: 1, endTime: 2, confidence: 0.95)
        ]

        // When
        let session = TranscriptionSession(
            id: id,
            startTime: startTime,
            endTime: endTime,
            duration: 60,
            wordCount: 25,
            averageConfidence: 0.92,
            context: "meeting",
            transcription: "Hello World",
            segments: segments,
            language: .spanish
        )

        // Then
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertEqual(session.endTime, endTime)
        XCTAssertEqual(session.duration, 60)
        XCTAssertEqual(session.wordCount, 25)
        XCTAssertEqual(session.averageConfidence, 0.92)
        XCTAssertEqual(session.context, "meeting")
        XCTAssertEqual(session.transcription, "Hello World")
        XCTAssertEqual(session.segments.count, 2)
        XCTAssertEqual(session.language, .spanish)
    }

    // MARK: - Metadata Tests

    func testSessionMetadataDefaultInitialization() {
        // When
        let metadata = TranscriptionSession.Metadata()

        // Then
        XCTAssertNil(metadata.appName)
        XCTAssertNil(metadata.appBundleID)
        XCTAssertEqual(metadata.customVocabularyHits, 0)
        XCTAssertEqual(metadata.correctionsApplied, 0)
        XCTAssertEqual(metadata.privacyMode, .balanced)
        XCTAssertNil(metadata.title)
        XCTAssertTrue(metadata.tags.isEmpty)
    }

    func testSessionMetadataCustomInitialization() {
        // Given/When
        let metadata = TranscriptionSession.Metadata(
            appName: "TestApp",
            appBundleID: "com.test.app",
            customVocabularyHits: 5,
            correctionsApplied: 3,
            privacyMode: .maximum,
            title: "Test Session",
            tags: ["important", "work"],
            language: "en-US",
            contextType: "meeting",
            privacy: "maximum",
            speaker: "John Doe",
            location: "Office"
        )

        // Then
        XCTAssertEqual(metadata.appName, "TestApp")
        XCTAssertEqual(metadata.appBundleID, "com.test.app")
        XCTAssertEqual(metadata.customVocabularyHits, 5)
        XCTAssertEqual(metadata.correctionsApplied, 3)
        XCTAssertEqual(metadata.privacyMode, .maximum)
        XCTAssertEqual(metadata.title, "Test Session")
        XCTAssertEqual(metadata.tags, ["important", "work"])
        XCTAssertEqual(metadata.language, "en-US")
        XCTAssertEqual(metadata.contextType, "meeting")
        XCTAssertEqual(metadata.speaker, "John Doe")
    }

    // MARK: - Codable Tests

    func testTranscriptionSessionCodable() throws {
        // Given
        let original = TranscriptionSession(
            startTime: Date(),
            duration: 120,
            wordCount: 150,
            averageConfidence: 0.88,
            context: "coding",
            transcription: "Test transcription text",
            segments: [
                TranscriptionSegment(text: "Test", startTime: 0, endTime: 1, confidence: 0.9)
            ],
            language: .french
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TranscriptionSession.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.wordCount, original.wordCount)
        XCTAssertEqual(decoded.averageConfidence, original.averageConfidence)
        XCTAssertEqual(decoded.context, original.context)
        XCTAssertEqual(decoded.transcription, original.transcription)
        XCTAssertEqual(decoded.segments.count, original.segments.count)
        XCTAssertEqual(decoded.language, original.language)
    }

    func testSessionMetadataCodable() throws {
        // Given
        let original = TranscriptionSession.Metadata(
            appName: "VoiceFlow",
            customVocabularyHits: 10,
            correctionsApplied: 5,
            privacyMode: .convenience,
            title: "Important Meeting",
            tags: ["meeting", "important", "Q4"]
        )

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionSession.Metadata.self, from: data)

        // Then
        XCTAssertEqual(decoded.appName, original.appName)
        XCTAssertEqual(decoded.customVocabularyHits, original.customVocabularyHits)
        XCTAssertEqual(decoded.correctionsApplied, original.correctionsApplied)
        XCTAssertEqual(decoded.privacyMode, original.privacyMode)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.tags, original.tags)
    }

    // MARK: - Session Lifecycle Tests

    func testSessionCreation() {
        // When
        let session = TranscriptionSession(
            startTime: Date(),
            language: .english
        )

        // Then
        XCTAssertNotNil(session.id)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.wordCount, 0)
        XCTAssertTrue(session.transcription.isEmpty)
    }

    func testSessionCompletion() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(300) // 5 minutes later

        // When
        let session = TranscriptionSession(
            startTime: startTime,
            endTime: endTime,
            duration: 300,
            wordCount: 500,
            averageConfidence: 0.91,
            transcription: "Completed transcription content"
        )

        // Then
        XCTAssertNotNil(session.endTime)
        XCTAssertEqual(session.duration, 300)
        XCTAssertEqual(session.wordCount, 500)
        XCTAssertFalse(session.transcription.isEmpty)
    }

    // MARK: - Segments Tests

    func testSessionWithMultipleSegments() {
        // Given
        let segments = [
            TranscriptionSegment(text: "Hello", startTime: 0, endTime: 1, confidence: 0.95),
            TranscriptionSegment(text: "how are", startTime: 1, endTime: 2.5, confidence: 0.90),
            TranscriptionSegment(text: "you today", startTime: 2.5, endTime: 4, confidence: 0.92)
        ]

        // When
        let session = TranscriptionSession(
            transcription: "Hello how are you today",
            segments: segments
        )

        // Then
        XCTAssertEqual(session.segments.count, 3)
        XCTAssertEqual(session.segments[0].text, "Hello")
        XCTAssertEqual(session.segments[1].duration, 1.5, accuracy: 0.001)
        XCTAssertEqual(session.segments[2].endTime, 4.0)
    }

    func testSessionSegmentsOrderPreservation() {
        // Given
        var segments: [TranscriptionSegment] = []
        for i in 0..<100 {
            segments.append(
                TranscriptionSegment(
                    text: "Word \(i)",
                    startTime: Double(i),
                    endTime: Double(i) + 0.5,
                    confidence: 0.9
                )
            )
        }

        // When
        let session = TranscriptionSession(segments: segments)

        // Then
        XCTAssertEqual(session.segments.count, 100)
        for (index, segment) in session.segments.enumerated() {
            XCTAssertEqual(segment.text, "Word \(index)")
            XCTAssertEqual(segment.startTime, Double(index))
        }
    }

    // MARK: - Language Tests

    func testSessionWithDifferentLanguages() {
        // Given
        let languages: [Language] = [.english, .spanish, .french, .german, .japanese]

        // When/Then
        for language in languages {
            let session = TranscriptionSession(language: language)
            XCTAssertEqual(session.language, language)
        }
    }

    // MARK: - Confidence Calculation Tests

    func testAverageConfidenceCalculation() {
        // Given - session with known confidence
        let session = TranscriptionSession(
            averageConfidence: 0.87,
            segments: [
                TranscriptionSegment(text: "Low", startTime: 0, endTime: 1, confidence: 0.75),
                TranscriptionSegment(text: "Medium", startTime: 1, endTime: 2, confidence: 0.85),
                TranscriptionSegment(text: "High", startTime: 2, endTime: 3, confidence: 0.95)
            ]
        )

        // Then
        XCTAssertEqual(session.averageConfidence, 0.87)

        // Calculate actual average from segments
        let actualAverage = session.segments.reduce(0.0) { $0 + Double($1.confidence) } / Double(session.segments.count)
        XCTAssertEqual(actualAverage, 0.85, accuracy: 0.01)
    }

    // MARK: - Context Tests

    func testSessionContextTypes() {
        // Given
        let contexts = ["general", "meeting", "coding", "email", "notes"]

        // When/Then
        for context in contexts {
            let session = TranscriptionSession(context: context)
            XCTAssertEqual(session.context, context)
        }
    }

    // MARK: - Performance Tests

    func testSessionCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = TranscriptionSession(
                    transcription: "Performance test transcription",
                    language: .english
                )
            }
        }
    }

    func testSessionWithLargeSegmentListPerformance() {
        // Given
        let largeSegmentList = (0..<10000).map { i in
            TranscriptionSegment(
                text: "Segment \(i)",
                startTime: Double(i),
                endTime: Double(i) + 1,
                confidence: 0.9
            )
        }

        // When/Then
        measure {
            _ = TranscriptionSession(segments: largeSegmentList)
        }
    }

    func testSessionCodingPerformance() throws {
        // Given
        let session = TranscriptionSession(
            transcription: "Test transcription for performance",
            segments: (0..<100).map { i in
                TranscriptionSegment(
                    text: "Word \(i)",
                    startTime: Double(i),
                    endTime: Double(i) + 0.5,
                    confidence: 0.9
                )
            }
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // When/Then
        measure {
            if let data = try? encoder.encode(session) {
                _ = try? decoder.decode(TranscriptionSession.self, from: data)
            }
        }
    }
}
