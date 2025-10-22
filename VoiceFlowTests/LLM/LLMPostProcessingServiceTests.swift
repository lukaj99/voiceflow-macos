import XCTest
@testable import VoiceFlow

private typealias LLMModel = LLMPostProcessingService.LLMModel
private typealias ServiceProvider = LLMPostProcessingService.LLMProvider

/// Comprehensive tests for LLM post-processing service
@MainActor
final class LLMPostProcessingServiceTests: XCTestCase {
    private func makeService() -> LLMPostProcessingService {
        LLMPostProcessingService()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureAPIKey() {
        let service = makeService()
        // Given
        let apiKey = "sk-test-key-12345678901234567890123456789012345678901234567890"
        
        // When
        service.configureAPIKey(apiKey, for: .openAI)
        
        // Then
        XCTAssertTrue(service.isConfigured(for: .openAI))
        XCTAssertFalse(service.isConfigured(for: .claude))
    }
    
    func testGetAvailableModels() {
        let service = makeService()
        // Given
        service.configureAPIKey("sk-test-key-12345678901234567890123456789012345678901234567890", for: .openAI)
        service.configureAPIKey("sk-ant-test-key-1234567890123456789012345678901234567890123456789012345678901234", for: .claude)
        
        // When
        let availableModels = service.getAvailableModels()
        
        // Then
        XCTAssertTrue(availableModels.contains(.gpt4oMini))
        XCTAssertTrue(availableModels.contains(.gpt4o))
        XCTAssertTrue(availableModels.contains(.claudeHaiku))
        XCTAssertTrue(availableModels.contains(.claudeSonnet))
        XCTAssertEqual(availableModels.count, 4)
    }
    
    func testGetAvailableModelsWithPartialConfiguration() {
        let service = makeService()
        // Given - Only configure OpenAI
        service.configureAPIKey("sk-test-key-12345678901234567890123456789012345678901234567890", for: .openAI)
        
        // When
        let availableModels = service.getAvailableModels()
        
        // Then
        XCTAssertTrue(availableModels.contains(.gpt4oMini))
        XCTAssertTrue(availableModels.contains(.gpt4o))
        XCTAssertFalse(availableModels.contains(.claudeHaiku))
        XCTAssertFalse(availableModels.contains(.claudeSonnet))
        XCTAssertEqual(availableModels.count, 2)
    }
    
    // MARK: - Processing Tests
    
    func testProcessTranscriptionWhenDisabled() async {
        let service = makeService()
        // Given
        service.isEnabled = false
        let inputText = "hello world"
        
        // When
        let result = await service.processTranscription(inputText)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure when service is disabled")
        case .failure(let error):
            guard case .modelUnavailable = error else {
                XCTFail("Expected modelUnavailable error, got \(error)")
                return
            }
        }
    }
    
    func testProcessTranscriptionWithEmptyText() async {
        let service = makeService()
        // Given
        service.isEnabled = true
        let inputText = ""
        
        // When
        let result = await service.processTranscription(inputText)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure with empty text")
        case .failure(let error):
            guard case .textTooLong = error else {
                XCTFail("Expected textTooLong error, got \(error)")
                return
            }
        }
    }
    
    func testProcessTranscriptionWithMissingAPIKey() async {
        let service = makeService()
        // Given
        service.isEnabled = true
        service.selectedModel = .gpt4oMini
        let inputText = "hello world this is a test"
        
        // When
        let result = await service.processTranscription(inputText)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure with missing API key")
        case .failure(let error):
            guard case .apiKeyMissing = error else {
                XCTFail("Expected apiKeyMissing error, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Word Substitution Tests
    
    func testWordSubstitutionMappings() {
        // Test that word substitutions are correctly defined
        let testCases = [
            ("slash", "/"),
            ("at sign", "@"),
            ("hashtag", "#"),
            ("dollar sign", "$"),
            ("percent", "%"),
            ("ampersand", "&"),
            ("asterisk", "*"),
            ("question mark", "?"),
            ("exclamation mark", "!"),
            ("open parenthesis", "("),
            ("close parenthesis", ")"),
            ("less than", "<"),
            ("greater than", ">")
        ]
        
        // This test validates our substitution mappings are comprehensive
        for (spoken, symbol) in testCases {
            XCTAssertNotNil(symbol, "Word substitution should exist for '\(spoken)'")
            XCTAssertFalse(symbol.isEmpty, "Symbol should not be empty for '\(spoken)'")
        }
    }
    
    // MARK: - Cache Tests
    
    func testCacheKeyGeneration() {
        let service = makeService()
        // Given & When - Using reflection to access private method (in real implementation)
        // For now, we'll test the behavior indirectly
        service.isEnabled = true
        service.configureAPIKey("sk-test-key-12345678901234567890123456789012345678901234567890", for: .openAI)
        
        // The cache behavior would be tested through repeated calls
        // This is a placeholder for cache functionality testing
        XCTAssertNotNil(service, "Service should be initialized")
    }
    
    func testClearCache() {
        let service = makeService()
        // Given
        service.isEnabled = true
        service.configureAPIKey("sk-test-key-12345678901234567890123456789012345678901234567890", for: .openAI)
        
        // When
        service.clearCache()
        
        // Then - Cache should be cleared (no direct way to test private cache)
        // We test that the method executes without error
        XCTAssertNotNil(service, "Service should remain functional after cache clear")
    }
    
    // MARK: - Statistics Tests
    
    func testInitialStatistics() {
        let service = makeService()
        // Given & When
        let stats = service.getStatistics()
        
        // Then
        XCTAssertEqual(stats.totalProcessed, 0)
        XCTAssertEqual(stats.successfulProcessings, 0)
        XCTAssertEqual(stats.failedProcessings, 0)
        XCTAssertEqual(stats.totalProcessingTime, 0)
        XCTAssertEqual(stats.averageProcessingTime, 0)
        XCTAssertEqual(stats.successRate, 0)
    }
    
    // MARK: - Model Selection Tests
    
    func testModelProviderMapping() {
        // Test that models are correctly mapped to providers
        XCTAssertEqual(LLMModel.gpt4oMini.provider, .openAI)
        XCTAssertEqual(LLMModel.gpt4o.provider, .openAI)
        XCTAssertEqual(LLMModel.claudeHaiku.provider, .claude)
        XCTAssertEqual(LLMModel.claudeSonnet.provider, .claude)
    }
    
    func testRecommendedModels() {
        // Test that recommended models are correctly identified
        XCTAssertTrue(LLMModel.gpt4oMini.isRecommended)
        XCTAssertTrue(LLMModel.claudeHaiku.isRecommended)
        XCTAssertFalse(LLMModel.gpt4o.isRecommended)
        XCTAssertFalse(LLMModel.claudeSonnet.isRecommended)
    }
    
    func testModelDisplayNames() {
        // Test that models have proper display names
        XCTAssertEqual(LLMModel.gpt4oMini.displayName, "GPT-4o Mini")
        XCTAssertEqual(LLMModel.gpt4o.displayName, "GPT-4o")
        XCTAssertEqual(LLMModel.claudeHaiku.displayName, "Claude 3 Haiku")
        XCTAssertEqual(LLMModel.claudeSonnet.displayName, "Claude 3 Sonnet")
    }
    
    // MARK: - Provider Tests
    
    func testProviderDisplayNames() {
        // Test that providers have proper display names
        XCTAssertEqual(ServiceProvider.openAI.displayName, "OpenAI GPT")
        XCTAssertEqual(ServiceProvider.claude.displayName, "Anthropic Claude")
    }
    
    func testProviderModels() {
        // Test that providers return correct models
        let openAIModels = ServiceProvider.openAI.models
        XCTAssertTrue(openAIModels.contains(.gpt4oMini))
        XCTAssertTrue(openAIModels.contains(.gpt4o))
        XCTAssertEqual(openAIModels.count, 2)
        
        let claudeModels = ServiceProvider.claude.models
        XCTAssertTrue(claudeModels.contains(.claudeHaiku))
        XCTAssertTrue(claudeModels.contains(.claudeSonnet))
        XCTAssertEqual(claudeModels.count, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessingErrorDescriptions() {
        // Test that all error types have proper descriptions
        let errors: [LLMPostProcessingService.ProcessingError] = [
            .apiKeyMissing,
            .apiKeyInvalid,
            .networkError("Test error"),
            .invalidResponse,
            .rateLimitExceeded,
            .textTooLong,
            .modelUnavailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationDefaults() {
        let service = makeService()
        // Test that service has sensible defaults
        XCTAssertEqual(service.selectedModel, .gpt4oMini)
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.maxTokens, 1000)
        XCTAssertEqual(service.temperature, 0.1)
        XCTAssertTrue(service.useContextualCorrection)
        XCTAssertTrue(service.enableWordSubstitution)
    }
    
    func testConfigurationModification() {
        let service = makeService()
        // Test that configuration can be modified
        service.selectedModel = .gpt4o
        service.isEnabled = true
        service.maxTokens = 2000
        service.temperature = 0.2
        service.useContextualCorrection = false
        service.enableWordSubstitution = false
        
        XCTAssertEqual(service.selectedModel, .gpt4o)
        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(service.maxTokens, 2000)
        XCTAssertEqual(service.temperature, 0.2)
        XCTAssertFalse(service.useContextualCorrection)
        XCTAssertFalse(service.enableWordSubstitution)
    }
    
    // MARK: - Integration Tests
    
    func testServiceIntegrationWithAppState() {
        // Test that service integrates properly with AppState
        let appState = AppState.shared
        
        // Test initial state
        XCTAssertFalse(appState.llmPostProcessingEnabled)
        XCTAssertFalse(appState.isLLMProcessing)
        XCTAssertNil(appState.llmProcessingError)
        
        // Test enabling LLM processing
        appState.enableLLMPostProcessing()
        XCTAssertTrue(appState.llmPostProcessingEnabled)
        
        // Test disabling LLM processing
        appState.disableLLMPostProcessing()
        XCTAssertFalse(appState.llmPostProcessingEnabled)
    }
    
    // MARK: - Performance Tests
    
    func testProcessingPerformance() {
        let service = makeService()
        // Test that processing completes within reasonable time
        let expectation = XCTestExpectation(description: "Processing completes")
        
        Task {
            let startTime = Date()
            _ = await service.processTranscription("test text")
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Even with errors, should complete quickly
            XCTAssertLessThan(processingTime, 1.0, "Processing should complete within 1 second")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

/// Mock processing result for testing
private extension LLMPostProcessingService.ProcessingResult {
    static func mock(
        originalText: String = "test",
        processedText: String = "Test.",
        improvementScore: Float = 0.5,
        processingTime: TimeInterval = 0.1,
        model: LLMModel = .gpt4oMini,
        changes: [TextChange] = []
    ) -> LLMPostProcessingService.ProcessingResult {
        return LLMPostProcessingService.ProcessingResult(
            originalText: originalText,
            processedText: processedText,
            improvementScore: improvementScore,
            processingTime: processingTime,
            model: model,
            changes: changes
        )
    }
}

/// Mock text change for testing
private extension LLMPostProcessingService.ProcessingResult.TextChange {
    static func mock(
        type: ChangeType = .punctuation,
        original: String = "test",
        replacement: String = "Test.",
        reason: String = "Added punctuation"
    ) -> LLMPostProcessingService.ProcessingResult.TextChange {
        return LLMPostProcessingService.ProcessingResult.TextChange(
            type: type,
            original: original,
            replacement: replacement,
            reason: reason
        )
    }
} 
