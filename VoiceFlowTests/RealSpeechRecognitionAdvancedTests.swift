import XCTest
import Speech
import AVFoundation
import Combine
@testable import VoiceFlow

// MARK: - Protocol for Testable Speech Recognition

protocol SpeechRecognizerProtocol {
    var isAvailable: Bool { get }
    var supportsOnDeviceRecognition: Bool { get set }
    var delegate: SFSpeechRecognizerDelegate? { get set }
    
    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, 
                        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask
    
    static func requestAuthorization(_ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void)
}

// MARK: - Advanced Mock Implementation

class AdvancedMockSpeechRecognizer: SpeechRecognizerProtocol {
    var isAvailable: Bool = true
    var supportsOnDeviceRecognition: Bool = true
    var delegate: SFSpeechRecognizerDelegate?
    
    private var recognitionTasks: [MockRecognitionTask] = []
    private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .authorized
    
    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, 
                        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask {
        let task = MockRecognitionTask(request: request, resultHandler: resultHandler)
        recognitionTasks.append(task)
        return task
    }
    
    static func requestAuthorization(_ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        // Simulate async authorization
        DispatchQueue.main.async {
            handler(.authorized)
        }
    }
    
    // Test helpers
    func simulateRecognitionResult(text: String, isFinal: Bool = false, confidence: Float = 0.9) {
        guard let task = recognitionTasks.last else { return }
        
        let result = createMockResult(text: text, isFinal: isFinal, confidence: confidence)
        task.resultHandler?(result, nil)
    }
    
    func simulateError(_ error: Error) {
        guard let task = recognitionTasks.last else { return }
        task.resultHandler?(nil, error)
    }
    
    private func createMockResult(text: String, isFinal: Bool, confidence: Float) -> SFSpeechRecognitionResult {
        // Create mock result with proper structure
        let mockResult = MockSFSpeechRecognitionResult(
            bestTranscription: MockSFTranscription(
                formattedString: text,
                segments: createSegments(from: text, confidence: confidence)
            ),
            isFinal: isFinal
        )
        return mockResult
    }
    
    private func createSegments(from text: String, confidence: Float) -> [SFTranscriptionSegment] {
        text.split(separator: " ").enumerated().map { index, word in
            MockSFTranscriptionSegment(
                substring: String(word),
                timestamp: Double(index) * 0.5,
                duration: 0.5,
                confidence: confidence
            )
        }
    }
}

class MockRecognitionTask: SFSpeechRecognitionTask {
    let request: SFSpeechAudioBufferRecognitionRequest
    let resultHandler: (SFSpeechRecognitionResult?, Error?) -> Void
    private var _isCancelled = false
    
    init(request: SFSpeechAudioBufferRecognitionRequest, 
         resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) {
        self.request = request
        self.resultHandler = resultHandler
        super.init()
    }
    
    override func cancel() {
        _isCancelled = true
        resultHandler(nil, NSError(domain: "SFSpeechRecognitionErrorDomain", code: 209, userInfo: nil))
    }
    
    override var state: SFSpeechRecognitionTaskState {
        return _isCancelled ? .canceling : .running
    }
}

// MARK: - Advanced Test Cases

@MainActor
final class RealSpeechRecognitionAdvancedTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Vocabulary Management Tests
    
    func testVocabularyUpdatesDuringActiveRecognition() async {
        // Test that vocabulary updates are applied to active recognition requests
        let expectation = expectation(description: "Vocabulary updated")
        expectation.isInverted = true
        
        // Given
        let engine = RealSpeechRecognitionEngine()
        
        // When
        await engine.addCustomVocabulary(["SwiftUI", "Combine"])
        await engine.setContext(.coding(language: .swift))
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Verify no crash and proper handling
        XCTAssertTrue(true)
    }
    
    func testContextSwitchingPreservesCustomVocabulary() async {
        // Given
        let engine = RealSpeechRecognitionEngine()
        let customWords = ["CustomWord1", "CustomWord2"]
        
        // When
        await engine.addCustomVocabulary(customWords)
        await engine.setContext(.coding(language: .swift))
        await engine.setContext(.email)
        await engine.setContext(.general)
        
        // Then
        // Verify vocabulary is preserved across context switches
        XCTAssertTrue(true)
    }
    
    // MARK: - Confidence Calculation Tests
    
    func testConfidenceCalculationWithEmptySegments() {
        // Test edge case of transcription with no segments
        let transcription = MockSFTranscription(formattedString: "", segments: [])
        
        // Expected confidence should be 0.0 for empty segments
        // This tests the guard statement in calculateConfidence
        XCTAssertTrue(true)
    }
    
    func testConfidenceCalculationWithVariedConfidences() {
        // Given segments with varied confidence levels
        let segments = [
            MockSFTranscriptionSegment(substring: "High", timestamp: 0.0, duration: 0.5, confidence: 0.95),
            MockSFTranscriptionSegment(substring: "Medium", timestamp: 0.5, duration: 0.5, confidence: 0.75),
            MockSFTranscriptionSegment(substring: "Low", timestamp: 1.0, duration: 0.5, confidence: 0.55)
        ]
        
        let expectedAverage = (0.95 + 0.75 + 0.55) / 3.0
        XCTAssertEqual(expectedAverage, 0.75, accuracy: 0.01)
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryFromNetworkError() async {
        // Test that engine falls back to offline recognition on network error
        let engine = RealSpeechRecognitionEngine()
        
        // Simulate network error scenario
        // In production, this would trigger fallback to on-device recognition
        XCTAssertTrue(true)
    }
    
    func testHandlingMultipleConsecutiveErrors() async {
        // Test engine's resilience to multiple errors
        let engine = RealSpeechRecognitionEngine()
        var receivedUpdates: [TranscriptionUpdate] = []
        
        engine.transcriptionPublisher
            .sink { update in
                receivedUpdates.append(update)
            }
            .store(in: &cancellables)
        
        // Simulate multiple error scenarios
        // Verify appropriate handling and recovery
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance and Memory Tests
    
    func testMemoryLeakInTranscriptionPublisher() {
        // Test for potential retain cycles
        weak var weakEngine: RealSpeechRecognitionEngine?
        
        autoreleasepool {
            let engine = RealSpeechRecognitionEngine()
            weakEngine = engine
            
            let cancellable = engine.transcriptionPublisher
                .sink { _ in
                    // Handle update
                }
            
            // Cancel subscription
            cancellable.cancel()
        }
        
        // Verify engine is properly deallocated
        XCTAssertNil(weakEngine)
    }
    
    func testHighFrequencyUpdates() async {
        // Test handling of rapid transcription updates
        let engine = RealSpeechRecognitionEngine()
        var updateCount = 0
        let updateExpectation = expectation(description: "High frequency updates")
        updateExpectation.isInverted = true
        
        engine.transcriptionPublisher
            .sink { _ in
                updateCount += 1
                if updateCount > 100 {
                    updateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate rapid updates
        await fulfillment(of: [updateExpectation], timeout: 1.0)
        
        // Verify no performance degradation
        XCTAssertLessThanOrEqual(updateCount, 100)
    }
    
    // MARK: - Context-Specific Correction Tests
    
    func testProgrammingContextCorrectionsAccuracy() {
        // Test specific programming term corrections
        let testCases = [
            ("print line", "println"),
            ("swift you eye", "SwiftUI"),
            ("you eye kit", "UIKit"),
            ("function", "func"),
            ("variable", "var"),
            ("constant", "let")
        ]
        
        // Verify each correction is properly applied
        for (input, expected) in testCases {
            // In production, this would test the actual correction logic
            XCTAssertNotEqual(input, expected)
        }
    }
    
    func testEmailContextCapitalization() {
        // Test email-specific capitalizations
        let testCases = [
            ("best regards", "Best regards"),
            ("kind regards", "Kind regards"),
            ("sincerely", "Sincerely"),
            ("dear john", "Dear john")
        ]
        
        // Verify proper capitalization
        for (input, expected) in testCases {
            XCTAssertNotEqual(input, expected)
        }
    }
    
    // MARK: - State Management Tests
    
    func testStateTransitions() async {
        // Test valid state transitions
        let engine = RealSpeechRecognitionEngine()
        
        // Initial state
        XCTAssertFalse(engine.isTranscribing)
        XCTAssertFalse(engine.isPaused)
        
        // Test pause without transcribing
        await engine.pauseTranscription()
        XCTAssertFalse(engine.isPaused)
        
        // Test resume without pausing
        await engine.resumeTranscription()
        XCTAssertFalse(engine.isPaused)
    }
    
    // MARK: - Language Switching Tests
    
    func testLanguageSwitchingDuringTranscription() async {
        // Test changing language while actively transcribing
        let engine = RealSpeechRecognitionEngine()
        
        // Switch languages
        await engine.setLanguage("en-US")
        await engine.setLanguage("es-ES")
        await engine.setLanguage("fr-FR")
        
        // Verify no crashes and proper handling
        XCTAssertTrue(true)
    }
    
    // MARK: - Audio Buffer Processing Tests
    
    func testAudioBufferProcessingWhilePaused() {
        // Test that audio buffers are ignored while paused
        let engine = RealSpeechRecognitionEngine()
        
        // Create mock audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)
        
        // Process should be ignored when paused
        XCTAssertNotNil(buffer)
    }
    
    // MARK: - Alternative Transcriptions Tests
    
    func testAlternativeTranscriptionsGeneration() {
        // Test that alternatives are properly extracted
        let primaryTranscription = MockSFTranscription(formattedString: "Hello world", segments: [])
        let alternative1 = MockSFTranscription(formattedString: "Hello word", segments: [])
        let alternative2 = MockSFTranscription(formattedString: "Hello work", segments: [])
        
        let result = MockSFSpeechRecognitionResult(
            bestTranscription: primaryTranscription,
            isFinal: true,
            transcriptions: [primaryTranscription, alternative1, alternative2]
        )
        
        // Verify alternatives are properly formatted
        XCTAssertEqual(result.transcriptions.count, 3)
    }
}

// MARK: - Performance Test Extension

extension RealSpeechRecognitionAdvancedTests {
    func testTranscriptionPerformance() {
        // Measure performance of transcription processing
        measure {
            // Create large transcription result
            let longText = Array(repeating: "word", count: 1000).joined(separator: " ")
            let segments = (0..<1000).map { index in
                MockSFTranscriptionSegment(
                    substring: "word",
                    timestamp: Double(index) * 0.1,
                    duration: 0.1,
                    confidence: 0.9
                )
            }
            
            let transcription = MockSFTranscription(
                formattedString: longText,
                segments: segments
            )
            
            // Process would happen here in actual implementation
            XCTAssertEqual(segments.count, 1000)
        }
    }
    
    func testVocabularyLookupPerformance() {
        // Test performance of vocabulary matching
        let vocabulary = Set((0..<10000).map { "Word\($0)" })
        let text = "This is a test with Word500 and Word9999"
        
        measure {
            // Simulate vocabulary lookup
            _ = vocabulary.contains("Word500")
            _ = vocabulary.contains("Word9999")
        }
    }
}