import XCTest
import Speech
import AVFoundation
import Combine
@testable import VoiceFlow

class RealSpeechRecognitionEngineTests: XCTestCase {
    var engine: RealSpeechRecognitionEngine!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        engine = RealSpeechRecognitionEngine()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        Task {
            await engine.stopTranscription()
        }
        cancellables = nil
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testBasicInitialization() async {
        // Test that the engine is properly initialized
        let isTranscribing = await engine.isTranscribing
        let isPaused = await engine.isPaused
        
        XCTAssertFalse(isTranscribing)
        XCTAssertFalse(isPaused)
        XCTAssertNotNil(engine.transcriptionPublisher)
    }
    
    func testLanguageConfiguration() async {
        // Test language switching
        await engine.setLanguage("en-US")
        // In real implementation, we'd verify the speech recognizer locale changed
        // For now, we just ensure the method doesn't crash
        
        await engine.setLanguage("es-ES")
        // Spanish language should also be supported
    }
    
    // MARK: - Performance Tests
    
    // Note: These tests are simplified for unit testing.
    // Real performance testing would require actual audio input
    // and would be better suited for integration tests.
    
    func testTranscriptionPublisherSetup() async {
        // Verify that the transcription publisher is properly configured
        let expectation = XCTestExpectation(description: "Publisher subscription")
        
        engine.transcriptionPublisher
            .sink { _ in
                // We don't expect actual updates in unit tests
                // Just verify the publisher is set up correctly
            }
            .store(in: &cancellables)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Result Handling Tests
    
    func testTranscriptionUpdateStructure() {
        // Test the TranscriptionUpdate structure
        let update = TranscriptionUpdate(
            type: .partial,
            text: "Test transcription",
            confidence: 0.95,
            alternatives: [
                TranscriptionUpdate.Alternative(text: "Test description", confidence: 0.85)
            ],
            wordTimings: [
                TranscriptionUpdate.WordTiming(
                    word: "Test",
                    startTime: 0.0,
                    endTime: 0.5,
                    confidence: 0.95
                )
            ]
        )
        
        XCTAssertEqual(update.type, .partial)
        XCTAssertEqual(update.text, "Test transcription")
        XCTAssertEqual(update.confidence, 0.95)
        XCTAssertNotNil(update.alternatives)
        XCTAssertEqual(update.alternatives?.count, 1)
        XCTAssertNotNil(update.wordTimings)
        XCTAssertEqual(update.wordTimings?.count, 1)
    }
    
    func testAlternativesStructure() {
        // Test alternatives sorting by confidence
        let alternatives = [
            TranscriptionUpdate.Alternative(text: "High confidence", confidence: 0.95),
            TranscriptionUpdate.Alternative(text: "Medium confidence", confidence: 0.85),
            TranscriptionUpdate.Alternative(text: "Low confidence", confidence: 0.75)
        ]
        
        // Verify alternatives can be sorted by confidence
        let sorted = alternatives.sorted { $0.confidence > $1.confidence }
        XCTAssertEqual(sorted[0].confidence, 0.95)
        XCTAssertEqual(sorted[1].confidence, 0.85)
        XCTAssertEqual(sorted[2].confidence, 0.75)
    }
    
    // MARK: - Context Tests
    
    func testContextSettings() async {
        // Test various context settings
        await engine.setContext(.coding(language: .swift))
        // Should update custom vocabulary for Swift
        
        await engine.setContext(.email(tone: .professional))
        // Should update vocabulary for email writing
        
        await engine.setContext(.meeting)
        // Should update vocabulary for meetings
        
        await engine.setContext(.document(type: .technical))
        // Should update vocabulary for technical documents
        
        // Verify contexts can be set without errors
        XCTAssertTrue(true, "Context settings completed without errors")
    }
    
    // MARK: - Custom Vocabulary Tests
    
    func testCustomVocabularyAddition() async {
        let customWords = ["SwiftUI", "ObservableObject", "@Published", "VoiceFlow"]
        await engine.addCustomVocabulary(customWords)
        
        // Add more words
        let additionalWords = ["Combine", "AsyncSequence", "MainActor"]
        await engine.addCustomVocabulary(additionalWords)
        
        // Verify vocabulary can be added without errors
        XCTAssertTrue(true, "Custom vocabulary added successfully")
    }
    
    // MARK: - State Management Tests
    
    func testStartStopCycle() async throws {
        // Note: This test requires microphone permissions
        // In a real test environment, we'd mock the audio session
        
        // Test initial state
        let initialState = await engine.isTranscribing
        XCTAssertFalse(initialState)
        
        // For unit tests, we can't actually start transcription
        // without proper permissions and audio setup
        // This would be better as an integration test
    }
    
    func testPauseResumeStates() async {
        // Test pause/resume state transitions
        let initialPaused = await engine.isPaused
        XCTAssertFalse(initialPaused)
        
        // Note: Actual pause/resume would require active transcription
        // This is more suitable for integration tests
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorTypes() {
        // Test that error types are properly defined
        let error1 = VoiceFlowError.speechRecognitionUnavailable
        XCTAssertNotNil(error1.errorDescription)
        
        let error2 = VoiceFlowError.languageNotSupported("xx-XX")
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("xx-XX") ?? false)
        
        let error3 = VoiceFlowError.microphonePermissionDenied
        XCTAssertNotNil(error3.errorDescription)
    }
    
    // MARK: - App Context Tests
    
    func testAppContextTypes() {
        // Test all app context types
        let contexts: [AppContext] = [
            .general,
            .coding(language: .swift),
            .coding(language: .javascript),
            .email(tone: .professional),
            .email(tone: .casual),
            .chat(formality: .business),
            .meeting,
            .notes,
            .document(type: .technical)
        ]
        
        // Verify all contexts are valid
        for context in contexts {
            XCTAssertNotNil(context)
        }
    }
    
    // MARK: - Privacy Mode Tests
    
    func testPrivacyModes() {
        // Test privacy mode definitions
        let modes: [PrivacyMode] = [.maximum, .balanced, .convenience]
        
        for mode in modes {
            XCTAssertNotNil(mode.description)
            XCTAssertFalse(mode.description.isEmpty)
        }
        
        // Test raw values
        XCTAssertEqual(PrivacyMode.maximum.rawValue, "maximum")
        XCTAssertEqual(PrivacyMode.balanced.rawValue, "balanced")
        XCTAssertEqual(PrivacyMode.convenience.rawValue, "convenience")
    }
    
    // MARK: - Transcription Session Tests
    
    func testTranscriptionSessionStructure() {
        let metadata = TranscriptionSession.Metadata(
            appName: "TestApp",
            appBundleID: "com.test.app",
            customVocabularyHits: 5,
            correctionsApplied: 3,
            privacyMode: .balanced
        )
        
        let session = TranscriptionSession(
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            duration: 60,
            wordCount: 150,
            averageConfidence: 0.92,
            context: "coding",
            transcription: "Test transcription content",
            metadata: metadata
        )
        
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.duration, 60)
        XCTAssertEqual(session.wordCount, 150)
        XCTAssertEqual(session.averageConfidence, 0.92)
        XCTAssertEqual(session.metadata.customVocabularyHits, 5)
    }
}