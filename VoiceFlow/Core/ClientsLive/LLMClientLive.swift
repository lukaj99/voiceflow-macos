import Dependencies
import Foundation

// MARK: - LLMClientLive

/// Live implementation of LLMClient wrapping LLMPostProcessingService.
extension LLMClient {
    /// Live implementation using the actual LLMPostProcessingService.
    public static var liveValue: LLMClient {
        // Use a sendable state holder
        let stateHolder = LLMStateHolder()

        return LLMClient(
            process: { text, model, options in
                try await stateHolder.process(text: text, model: model, options: options)
            },
            availableProviders: {
                LLMProvider.allCases
            },
            availableModels: { provider in
                provider.models
            },
            isProviderConfigured: { _ in
                false // Checked via state
            },
            cancelProcessing: {
                // Not implemented - would require task management
            },
            isProcessing: {
                false // Checked via state
            }
        )
    }
}

// MARK: - LLMProcessingError

/// Errors that can occur during LLM processing.
public enum LLMProcessingError: Error, LocalizedError {
    case apiKeyMissing
    case apiKeyInvalid
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case textTooLong
    case modelUnavailable
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing"
        case .apiKeyInvalid:
            return "API key is invalid"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .textTooLong:
            return "Text is too long for processing"
        case .modelUnavailable:
            return "Model is unavailable"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }

    /// Convert from ProcessingError to LLMProcessingError.
    static func from(_ error: ProcessingError) -> LLMProcessingError {
        switch error {
        case .apiKeyMissing:
            return .apiKeyMissing
        case .apiKeyInvalid:
            return .apiKeyInvalid
        case .networkError(let message):
            return .networkError(message)
        case .invalidResponse:
            return .invalidResponse
        case .rateLimitExceeded:
            return .rateLimitExceeded
        case .textTooLong:
            return .textTooLong
        case .modelUnavailable:
            return .modelUnavailable
        case .apiCallFailed(let message):
            return .processingFailed(message)
        }
    }
}

// MARK: - LLMStateHolder

/// Sendable state holder for LLM client.
/// Since all methods are @MainActor, no locks are needed.
@MainActor
private final class LLMStateHolder: @unchecked Sendable {
    private var llmService: LLMPostProcessingService?

    nonisolated init() {}

    private func getOrCreateService() -> LLMPostProcessingService {
        if let existing = llmService {
            return existing
        }
        let service = LLMPostProcessingService()
        llmService = service
        return service
    }

    func process(text: String, model: LLMModel, options: LLMProcessingOptions) async throws -> String {
        let service = getOrCreateService()

        // Configure the service
        service.selectedModel = model
        service.isEnabled = true
        service.temperature = Float(options.temperature)
        service.maxTokens = options.maxTokens

        // Process
        let result = await service.processTranscription(text, context: options.systemPrompt)

        switch result {
        case .success(let processingResult):
            return processingResult.processedText
        case .failure(let error):
            throw LLMProcessingError.from(error)
        }
    }
}
