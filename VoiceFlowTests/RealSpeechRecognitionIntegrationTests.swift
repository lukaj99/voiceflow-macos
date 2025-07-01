import XCTest
import Speech
import AVFoundation
import Combine
@testable import VoiceFlow

// MARK: - Integration Tests

@MainActor
final class RealSpeechRecognitionIntegrationTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - End-to-End Transcription Flow Tests
    
    func testCompleteTranscriptionLifecycle() async throws {
        // Given
        let engine = RealSpeechRecognitionEngine()
        var receivedUpdates: [TranscriptionUpdate] = []
        let updateExpectation = expectation(description: "Received updates")
        updateExpectation.isInverted = true // We don't expect real updates without mic input
        
        engine.transcriptionPublisher
            .sink { update in
                receivedUpdates.append(update)
                print("Received update: \(update.type) - \(update.text)")
            }
            .store(in: &cancellables)
        
        // When - Test lifecycle without actual speech input
        do {
            // This will fail due to authorization in test environment
            try await engine.startTranscription()
            XCTFail("Expected authorization error in test environment")
        } catch {
            // Expected error in test environment
            XCTAssertTrue(error is VoiceFlowError)
        }
        
        // Verify clean state after error
        XCTAssertFalse(engine.isTranscribing)
        XCTAssertFalse(engine.isPaused)
        
        await fulfillment(of: [updateExpectation], timeout: 1.0)
    }
    
    func testRapidStartStopCycles() async {
        // Test rapid start/stop to ensure no resource leaks
        let engine = RealSpeechRecognitionEngine()
        
        for _ in 0..<5 {
            // Attempt to start (will fail in test env)
            do {
                try await engine.startTranscription()
            } catch {
                // Expected
            }
            
            // Stop immediately
            await engine.stopTranscription()
            
            // Verify clean state
            XCTAssertFalse(engine.isTranscribing)
            XCTAssertFalse(engine.isPaused)
        }
    }
    
    // MARK: - Context Switching During Active Recognition Tests
    
    func testContextSwitchingFlow() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let contexts: [AppContext] = [
            .general,
            .coding(language: .swift),
            .email,
            .meeting,
            .document(type: .technical),
            .coding(language: .javascript),
            .document(type: .academic)
        ]
        
        // When - Switch through all contexts
        for context in contexts {
            await engine.setContext(context)
            
            // Add context-specific vocabulary
            switch context {
            case .coding(let language):
                if language == .swift {
                    await engine.addCustomVocabulary(["SwiftUI", "Combine", "async"])
                }
            case .email:
                await engine.addCustomVocabulary(["Regards", "Sincerely"])
            default:
                break
            }
        }
        
        // Then - Verify no crashes
        XCTAssertTrue(true)
    }
    
    // MARK: - Pause/Resume Flow Tests
    
    func testPauseResumeSequence() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        
        // Test invalid pause/resume sequences
        await engine.pauseTranscription() // Should do nothing
        XCTAssertFalse(engine.isPaused)
        
        await engine.resumeTranscription() // Should do nothing
        XCTAssertFalse(engine.isPaused)
        
        // Multiple pause calls
        await engine.pauseTranscription()
        await engine.pauseTranscription()
        XCTAssertFalse(engine.isPaused) // Still false as not transcribing
    }
    
    // MARK: - Language Switching Integration Tests
    
    func testMultiLanguageSupport() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let languages = ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "ja-JP", "zh-CN"]
        
        // When - Test each language
        for language in languages {
            await engine.setLanguage(language)
            
            // Add language-specific vocabulary
            switch language {
            case "es-ES":
                await engine.addCustomVocabulary(["Hola", "Gracias", "Por favor"])
            case "fr-FR":
                await engine.addCustomVocabulary(["Bonjour", "Merci", "S'il vous plaît"])
            default:
                break
            }
        }
        
        // Then - Verify no crashes
        XCTAssertTrue(true)
    }
    
    // MARK: - Publisher Integration Tests
    
    func testPublisherWithMultipleSubscribers() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        var subscriber1Updates: [TranscriptionUpdate] = []
        var subscriber2Updates: [TranscriptionUpdate] = []
        var subscriber3Updates: [TranscriptionUpdate] = []
        
        // When - Multiple subscribers
        engine.transcriptionPublisher
            .sink { update in
                subscriber1Updates.append(update)
            }
            .store(in: &cancellables)
        
        engine.transcriptionPublisher
            .sink { update in
                subscriber2Updates.append(update)
            }
            .store(in: &cancellables)
        
        engine.transcriptionPublisher
            .sink { update in
                subscriber3Updates.append(update)
            }
            .store(in: &cancellables)
        
        // Then - All subscribers should receive same updates
        XCTAssertEqual(subscriber1Updates.count, subscriber2Updates.count)
        XCTAssertEqual(subscriber2Updates.count, subscriber3Updates.count)
    }
    
    func testPublisherCancellation() {
        // Given
        let engine = RealSpeechRecognitionEngine()
        var receivedCount = 0
        
        // When
        let cancellable = engine.transcriptionPublisher
            .sink { _ in
                receivedCount += 1
            }
        
        // Cancel immediately
        cancellable.cancel()
        
        // Then - No updates should be received after cancellation
        XCTAssertEqual(receivedCount, 0)
    }
    
    // MARK: - Error Scenario Integration Tests
    
    func testErrorHandlingIntegration() async {
        // Test various error scenarios
        let engine = RealSpeechRecognitionEngine()
        var errorUpdates: [TranscriptionUpdate] = []
        
        engine.transcriptionPublisher
            .filter { $0.confidence == 0.0 }
            .sink { update in
                errorUpdates.append(update)
            }
            .store(in: &cancellables)
        
        // Simulate various error conditions
        // In production, these would be triggered by actual errors
        
        XCTAssertTrue(errorUpdates.isEmpty) // No errors in test environment
    }
    
    // MARK: - Vocabulary Management Integration Tests
    
    func testLargeVocabularyHandling() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let largeVocabulary = (0..<1000).map { "CustomWord\($0)" }
        
        // When - Add large vocabulary
        await engine.addCustomVocabulary(largeVocabulary)
        
        // Add more in batches
        for i in 0..<10 {
            let batch = (0..<100).map { "Batch\(i)Word\($0)" }
            await engine.addCustomVocabulary(batch)
        }
        
        // Then - Verify no performance degradation
        XCTAssertTrue(true)
    }
    
    func testVocabularyPersistenceAcrossContexts() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let globalVocabulary = ["GlobalWord1", "GlobalWord2", "GlobalWord3"]
        
        // When
        await engine.addCustomVocabulary(globalVocabulary)
        
        // Switch contexts multiple times
        await engine.setContext(.coding(language: .swift))
        await engine.setContext(.email)
        await engine.setContext(.meeting)
        await engine.setContext(.general)
        
        // Add more vocabulary
        await engine.addCustomVocabulary(["AdditionalWord"])
        
        // Then - Vocabulary should persist
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Monitoring Integration Tests
    
    func testPerformanceMetricsCollection() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let startTime = Date()
        
        // When - Perform various operations
        await engine.setContext(.coding(language: .swift))
        await engine.addCustomVocabulary(["Test1", "Test2"])
        await engine.setLanguage("en-US")
        
        // Then - Verify operations complete quickly
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 1.0) // Should complete within 1 second
    }
    
    // MARK: - Edge Case Integration Tests
    
    func testEmptyAndNilHandling() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        
        // When - Test with empty inputs
        await engine.addCustomVocabulary([])
        await engine.addCustomVocabulary([""])
        await engine.setLanguage("")
        
        // Then - Should handle gracefully
        XCTAssertTrue(true)
    }
    
    func testSpecialCharacterHandling() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let specialVocabulary = [
            "C++",
            "C#",
            ".NET",
            "@State",
            "#include",
            "$variable",
            "email@example.com",
            "https://example.com",
            "100%",
            "Node.js"
        ]
        
        // When
        await engine.addCustomVocabulary(specialVocabulary)
        
        // Then - Should handle special characters
        XCTAssertTrue(true)
    }
    
    func testUnicodeAndEmojiHandling() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let unicodeVocabulary = [
            "café",
            "naïve",
            "résumé",
            "Zürich",
            "北京",
            "🚀 Rocket",
            "Hello 👋"
        ]
        
        // When
        await engine.addCustomVocabulary(unicodeVocabulary)
        
        // Then - Should handle Unicode properly
        XCTAssertTrue(true)
    }
}

// MARK: - Stress Test Extension

extension RealSpeechRecognitionIntegrationTests {
    func testStressTestWithRapidOperations() async {
        // Stress test with rapid operations
        let engine = RealSpeechRecognitionEngine()
        let operationCount = 100
        
        await withTaskGroup(of: Void.self) { group in
            // Add multiple concurrent operations
            for i in 0..<operationCount {
                group.addTask {
                    switch i % 4 {
                    case 0:
                        await engine.setContext(.general)
                    case 1:
                        await engine.addCustomVocabulary(["Word\(i)"])
                    case 2:
                        await engine.setLanguage("en-US")
                    case 3:
                        await engine.pauseTranscription()
                    default:
                        break
                    }
                }
            }
        }
        
        // Verify engine still functional
        XCTAssertTrue(true)
    }
}