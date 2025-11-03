import XCTest
@testable import VoiceFlow

/// Comprehensive tests for TranscriptionUpdate model and related types
final class TranscriptionModelsTests: XCTestCase {

    // MARK: - TranscriptionUpdate Tests

    func testTranscriptionUpdateInitialization() {
        // Given
        let text = "Hello world"
        let confidence = 0.95

        // When
        let update = TranscriptionUpdate(
            type: .final,
            text: text,
            confidence: confidence
        )

        // Then
        XCTAssertNotNil(update.id)
        XCTAssertNotNil(update.timestamp)
        XCTAssertEqual(update.type, .final)
        XCTAssertEqual(update.text, text)
        XCTAssertEqual(update.confidence, confidence)
        XCTAssertNil(update.alternatives)
        XCTAssertNil(update.wordTimings)
    }

    func testTranscriptionUpdateWithAlternatives() {
        // Given
        let alternatives = [
            TranscriptionUpdate.Alternative(text: "Hello world", confidence: 0.95),
            TranscriptionUpdate.Alternative(text: "Hello word", confidence: 0.75)
        ]

        // When
        let update = TranscriptionUpdate(
            type: .partial,
            text: "Hello world",
            confidence: 0.95,
            alternatives: alternatives
        )

        // Then
        XCTAssertEqual(update.alternatives?.count, 2)
        XCTAssertEqual(update.alternatives?.first?.text, "Hello world")
        XCTAssertEqual(update.alternatives?.first?.confidence, 0.95)
    }

    func testTranscriptionUpdateWithWordTimings() {
        // Given
        let wordTimings = [
            TranscriptionUpdate.WordTiming(word: "Hello", startTime: 0.0, endTime: 0.5, confidence: 0.95),
            TranscriptionUpdate.WordTiming(word: "world", startTime: 0.5, endTime: 1.0, confidence: 0.93)
        ]

        // When
        let update = TranscriptionUpdate(
            type: .final,
            text: "Hello world",
            confidence: 0.94,
            wordTimings: wordTimings
        )

        // Then
        XCTAssertEqual(update.wordTimings?.count, 2)
        XCTAssertEqual(update.wordTimings?.first?.word, "Hello")
        XCTAssertEqual(update.wordTimings?.first?.startTime, 0.0)
        XCTAssertEqual(update.wordTimings?.first?.endTime, 0.5)
    }

    func testTranscriptionUpdateTypes() {
        // Given/When
        let partial = TranscriptionUpdate(type: .partial, text: "Hello", confidence: 0.8)
        let final = TranscriptionUpdate(type: .final, text: "Hello world", confidence: 0.95)
        let correction = TranscriptionUpdate(type: .correction, text: "Hello, world!", confidence: 0.97)

        // Then
        XCTAssertEqual(partial.type, .partial)
        XCTAssertEqual(final.type, .final)
        XCTAssertEqual(correction.type, .correction)
    }

    func testTranscriptionUpdateCodable() throws {
        // Given
        let original = TranscriptionUpdate(
            type: .final,
            text: "Test transcription",
            confidence: 0.92,
            alternatives: [
                TranscriptionUpdate.Alternative(text: "Test transcription", confidence: 0.92)
            ]
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TranscriptionUpdate.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.confidence, original.confidence)
        XCTAssertEqual(decoded.alternatives?.count, original.alternatives?.count)
    }

    // MARK: - TranscriptionSegment Tests

    func testTranscriptionSegmentInitialization() {
        // Given
        let text = "This is a segment"
        let startTime: TimeInterval = 10.0
        let endTime: TimeInterval = 15.0
        let confidence: Float = 0.89

        // When
        let segment = TranscriptionSegment(
            text: text,
            startTime: startTime,
            endTime: endTime,
            confidence: confidence
        )

        // Then
        XCTAssertEqual(segment.text, text)
        XCTAssertEqual(segment.startTime, startTime)
        XCTAssertEqual(segment.endTime, endTime)
        XCTAssertEqual(segment.confidence, confidence)
    }

    func testTranscriptionSegmentDuration() {
        // Given
        let segment = TranscriptionSegment(
            text: "Test",
            startTime: 5.0,
            endTime: 12.5,
            confidence: 0.95
        )

        // When
        let duration = segment.duration

        // Then
        XCTAssertEqual(duration, 7.5, accuracy: 0.001)
    }

    func testTranscriptionSegmentCodable() throws {
        // Given
        let original = TranscriptionSegment(
            text: "Codable test",
            startTime: 0.0,
            endTime: 3.5,
            confidence: 0.88
        )

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionSegment.self, from: data)

        // Then
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.endTime, original.endTime)
        XCTAssertEqual(decoded.confidence, original.confidence)
    }

    // MARK: - Language Tests

    func testLanguageDisplayNames() {
        // Given/When/Then
        XCTAssertEqual(Language.english.displayName, "English")
        XCTAssertEqual(Language.spanish.displayName, "Spanish")
        XCTAssertEqual(Language.french.displayName, "French")
        XCTAssertEqual(Language.german.displayName, "German")
        XCTAssertEqual(Language.japanese.displayName, "Japanese")
    }

    func testLanguageRawValues() {
        // Given/When/Then
        XCTAssertEqual(Language.english.rawValue, "en-US")
        XCTAssertEqual(Language.spanish.rawValue, "es-ES")
        XCTAssertEqual(Language.chinese.rawValue, "zh-CN")
    }

    func testLanguageLocale() {
        // Given
        let language = Language.english

        // When
        let locale = language.locale

        // Then
        XCTAssertEqual(locale.identifier, "en-US")
    }

    func testLanguageCaseIterable() {
        // Given/When
        let allLanguages = Language.allCases

        // Then
        XCTAssertGreaterThan(allLanguages.count, 0)
        XCTAssertTrue(allLanguages.contains(.english))
        XCTAssertTrue(allLanguages.contains(.spanish))
    }

    // MARK: - AppContext Tests

    func testAppContextEquality() {
        // Given/When/Then
        XCTAssertEqual(AppContext.general, AppContext.general)
        XCTAssertEqual(AppContext.meeting, AppContext.meeting)
        XCTAssertEqual(
            AppContext.coding(language: .swift),
            AppContext.coding(language: .swift)
        )
        XCTAssertNotEqual(
            AppContext.coding(language: .swift),
            AppContext.coding(language: .python)
        )
    }

    func testAppContextCodingLanguages() {
        // Given/When
        let languages = AppContext.CodingLanguage.allCases

        // Then
        XCTAssertTrue(languages.contains(.swift))
        XCTAssertTrue(languages.contains(.python))
        XCTAssertTrue(languages.contains(.javascript))
        XCTAssertGreaterThanOrEqual(languages.count, 8)
    }

    func testAppContextEmailTones() {
        // Given/When
        let tones = AppContext.EmailTone.allCases

        // Then
        XCTAssertTrue(tones.contains(.professional))
        XCTAssertTrue(tones.contains(.casual))
        XCTAssertTrue(tones.contains(.formal))
    }

    // MARK: - PrivacyMode Tests

    func testPrivacyModeDescriptions() {
        // Given/When/Then
        XCTAssertTrue(PrivacyMode.maximum.description.contains("No data leaves"))
        XCTAssertTrue(PrivacyMode.balanced.description.contains("Anonymous"))
        XCTAssertTrue(PrivacyMode.convenience.description.contains("encryption"))
    }

    func testPrivacyModeCodable() throws {
        // Given
        let mode = PrivacyMode.balanced

        // When
        let encoded = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(PrivacyMode.self, from: encoded)

        // Then
        XCTAssertEqual(decoded, mode)
    }

    // MARK: - TimeInterval Extension Tests

    func testTimeIntervalHumanReadable() {
        // Given/When/Then
        XCTAssertEqual((0 as TimeInterval).humanReadable, "0:00")
        XCTAssertEqual((45 as TimeInterval).humanReadable, "0:45")
        XCTAssertEqual((90 as TimeInterval).humanReadable, "1:30")
        XCTAssertEqual((3665 as TimeInterval).humanReadable, "1:01:05")
        XCTAssertEqual((7384 as TimeInterval).humanReadable, "2:03:04")
    }

    // MARK: - TranscriptionMetrics Tests

    func testTranscriptionMetricsInitialization() {
        // Given/When
        let metrics = TranscriptionMetrics(
            latency: 0.15,
            confidence: 0.92,
            wordCount: 42,
            processingTime: 0.25
        )

        // Then
        XCTAssertEqual(metrics.latency, 0.15)
        XCTAssertEqual(metrics.confidence, 0.92)
        XCTAssertEqual(metrics.wordCount, 42)
        XCTAssertEqual(metrics.processingTime, 0.25)
    }

    // MARK: - Performance Tests

    func testTranscriptionUpdateCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = TranscriptionUpdate(
                    type: .partial,
                    text: "Performance test transcription",
                    confidence: 0.85
                )
            }
        }
    }

    func testTranscriptionSegmentDurationCalculationPerformance() {
        // Given
        let segments = (0..<10000).map { i in
            TranscriptionSegment(
                text: "Segment \(i)",
                startTime: Double(i),
                endTime: Double(i) + 1.5,
                confidence: 0.9
            )
        }

        // When/Then
        measure {
            _ = segments.map(\.duration)
        }
    }
}
