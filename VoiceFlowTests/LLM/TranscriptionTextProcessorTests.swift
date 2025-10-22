import XCTest
@testable import VoiceFlow

@MainActor
final class TranscriptionTextProcessorTests: XCTestCase {
    func test_processTranscript_whenLLMDisabled_returnsCleanedText() async {
        let appState = MockLLMAppState()
        appState.llmPostProcessingEnabled = false
        appState.hasLLMProvidersConfigured = false
        let llmService = MockLLMPostProcessingService()
        llmService.isEnabled = true

        let processor = TranscriptionTextProcessor(llmService: llmService, appState: appState)

        let output = await processor.processTranscript("  hello   WORLD  ", isFinal: true)

        XCTAssertEqual(output, "Hello WORLD")
        XCTAssertEqual(llmService.processCallCount, 0)
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertTrue(appState.recordedResults.isEmpty)
        XCTAssertNil(appState.lastError)
    }

    func test_processTranscript_whenLLMEnabled_appliesEnhancement() async {
        let appState = MockLLMAppState()
        appState.llmPostProcessingEnabled = true
        appState.hasLLMProvidersConfigured = true

        let llmService = MockLLMPostProcessingService()
        llmService.isEnabled = true
        llmService.nextResult = .success(
            LLMPostProcessingService.ProcessingResult(
                originalText: "Hello world",
                processedText: "Hello, world!",
                improvementScore: 0.8,
                processingTime: 0.12,
                model: .gpt4oMini,
                changes: [
                    .init(
                        type: .punctuation,
                        original: "missing comma",
                        replacement: "added comma",
                        reason: "Improved readability"
                    )
                ]
            )
        )

        let processor = TranscriptionTextProcessor(llmService: llmService, appState: appState)

        let output = await processor.processTranscript("hello world", isFinal: true)

        XCTAssertEqual(output, "Hello, world!")
        XCTAssertEqual(llmService.processCallCount, 1)
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertNil(appState.lastError)
        XCTAssertEqual(appState.recordedResults.count, 1)
        XCTAssertTrue(appState.recordedResults.first?.success ?? false)
        XCTAssertGreaterThan(appState.recordedResults.first?.improvementScore ?? 0, 0)
    }

    func test_processTranscript_whenLLMProcessingFails_surfacesError() async {
        let appState = MockLLMAppState()
        appState.llmPostProcessingEnabled = true
        appState.hasLLMProvidersConfigured = true

        let llmService = MockLLMPostProcessingService()
        llmService.isEnabled = true
        llmService.nextResult = .failure(.networkError("offline"))

        let processor = TranscriptionTextProcessor(llmService: llmService, appState: appState)

        let output = await processor.processTranscript("final text with extra words", isFinal: true)

        XCTAssertEqual(output, "Final text with extra words")
        XCTAssertEqual(llmService.processCallCount, 1)
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertEqual(
            appState.lastError,
            LLMPostProcessingService.ProcessingError.networkError("offline").localizedDescription
        )
        XCTAssertEqual(appState.recordedResults.count, 1)
        XCTAssertFalse(appState.recordedResults.first?.success ?? true)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockLLMPostProcessingService: LLMPostProcessingService {
    var processCallCount = 0
    var receivedRequests: [(text: String, context: String?)] = []
    var nextResult: Result<ProcessingResult, ProcessingError> = .failure(.modelUnavailable)

    override func processTranscription(_ text: String, context: String? = nil) async -> Result<ProcessingResult, ProcessingError> {
        guard isEnabled else {
            return .failure(.modelUnavailable)
        }

        processCallCount += 1
        receivedRequests.append((text, context))
        return nextResult
    }
}

@MainActor
private final class MockLLMAppState: LLMProcessingStateManaging {
    var llmPostProcessingEnabled: Bool = false
    var hasLLMProvidersConfigured: Bool = false
    var isLLMProcessing: Bool = false
    var lastProgress: Float?
    var lastError: String?
    var recordedResults: [(success: Bool, processingTime: TimeInterval, improvementScore: Float)] = []
    var providerSelections: [(String, String)] = []
    var configurationUpdates: [Bool] = []

    func enableLLMPostProcessing() {
        llmPostProcessingEnabled = true
    }

    func disableLLMPostProcessing() {
        llmPostProcessingEnabled = false
    }

    func setLLMProcessing(_ processing: Bool, progress: Float) {
        isLLMProcessing = processing
        lastProgress = progress
        if processing {
            lastError = nil
        }
    }

    func setLLMProcessingError(_ error: String?) {
        lastError = error
        if error != nil {
            isLLMProcessing = false
            lastProgress = 0
        }
    }

    func setSelectedLLMProvider(_ provider: String, model: String) {
        providerSelections.append((provider, model))
    }

    func updateLLMConfigurationStatus(_ hasProviders: Bool) {
        hasLLMProvidersConfigured = hasProviders
        configurationUpdates.append(hasProviders)
    }

    func recordLLMProcessingResult(success: Bool, processingTime: TimeInterval, improvementScore: Float) {
        recordedResults.append((success, processingTime, improvementScore))
    }
}
