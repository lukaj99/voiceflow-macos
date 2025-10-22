import XCTest
@testable import VoiceFlow

@MainActor
final class AppStateLLMStateTests: XCTestCase {
    func testLLMEnableDisableUpdatesState() {
        let state = AppState()

        XCTAssertFalse(state.llmPostProcessingEnabled)
        XCTAssertFalse(state.isLLMProcessing)
        XCTAssertNil(state.llmProcessingError)

        state.enableLLMPostProcessing()
        XCTAssertTrue(state.llmPostProcessingEnabled)

        state.setLLMProcessing(true, progress: 0.3)
        XCTAssertTrue(state.isLLMProcessing)
        XCTAssertEqual(state.llmProcessingProgress, 0.3, accuracy: 0.001)
        XCTAssertNil(state.llmProcessingError)

        state.setLLMProcessingError("LLM Failure")
        XCTAssertEqual(state.llmProcessingError, "LLM Failure")
        XCTAssertFalse(state.isLLMProcessing)
        XCTAssertEqual(state.llmProcessingProgress, 0.0, accuracy: 0.001)

        state.disableLLMPostProcessing()
        XCTAssertFalse(state.llmPostProcessingEnabled)
        XCTAssertFalse(state.isLLMProcessing)
        XCTAssertEqual(state.llmProcessingProgress, 0.0, accuracy: 0.001)
        XCTAssertNil(state.llmProcessingError)
    }

    func testLLMStatisticsAggregation() {
        let state = AppState()

        XCTAssertEqual(state.llmProcessingStats.totalProcessed, 0)

        state.recordLLMProcessingResult(success: true, processingTime: 1.2, improvementScore: 0.6)
        state.recordLLMProcessingResult(success: false, processingTime: 0.8, improvementScore: 0.0)

        XCTAssertEqual(state.llmProcessingStats.totalProcessed, 2)
        XCTAssertEqual(state.llmProcessingStats.successfulProcessings, 1)
        XCTAssertEqual(state.llmProcessingStats.failedProcessings, 1)
        XCTAssertEqual(state.llmProcessingStats.averageProcessingTime, 1.0, accuracy: 0.001)
        XCTAssertEqual(state.llmProcessingStats.successRate, 0.5, accuracy: 0.001)
    }

    func testLLMProviderSelection() {
        let state = AppState()

        state.setSelectedLLMProvider("openai", model: "gpt-4o-mini")
        XCTAssertEqual(state.selectedLLMProvider, "openai")
        XCTAssertEqual(state.selectedLLMModel, "gpt-4o-mini")

        state.updateLLMConfigurationStatus(true)
        XCTAssertTrue(state.hasLLMProvidersConfigured)
    }
}
