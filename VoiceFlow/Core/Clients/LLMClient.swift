import Dependencies
import DependenciesMacros
import Foundation

// MARK: - LLMProcessingOptions

/// Options for LLM processing.
public struct LLMProcessingOptions: Sendable, Equatable {
    public let temperature: Double
    public let maxTokens: Int
    public let systemPrompt: String?

    public init(
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        systemPrompt: String? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
    }

    public static let `default` = LLMProcessingOptions()

    public static let cleanup = LLMProcessingOptions(
        temperature: 0.3,
        maxTokens: 4096,
        systemPrompt: """
            You are a professional transcription editor. Clean up the transcription by:
            - Fixing obvious speech recognition errors
            - Adding proper punctuation and capitalization
            - Removing filler words (um, uh, like, you know)
            - Keeping the original meaning intact
            - Not adding information not in the original
            """
    )
}

// MARK: - LLMClient

/// Client for LLM post-processing of transcriptions.
/// Note: Uses LLMProvider and LLMModel from LLMModels.swift
@DependencyClient
public struct LLMClient: Sendable {
    /// Process text with an LLM.
    /// - Parameters:
    ///   - text: The text to process.
    ///   - model: The LLM model to use.
    ///   - options: Processing options.
    /// - Returns: The processed text.
    public var process: @Sendable (
        _ text: String,
        _ model: LLMModel,
        _ options: LLMProcessingOptions
    ) async throws -> String

    /// Get available providers.
    public var availableProviders: @Sendable () -> [LLMProvider] = {
        LLMProvider.allCases
    }

    /// Get available models for a provider.
    public var availableModels: @Sendable (_ provider: LLMProvider) -> [LLMModel] = { provider in
        provider.models
    }

    /// Check if a provider is configured (has API key if required).
    public var isProviderConfigured: @Sendable (_ provider: LLMProvider) -> Bool = { _ in false }

    /// Cancel any ongoing processing.
    public var cancelProcessing: @Sendable () -> Void = { }

    /// Whether processing is currently in progress.
    public var isProcessing: @Sendable () -> Bool = { false }
}

// MARK: - DependencyKey

extension LLMClient: DependencyKey {
    public static var testValue: LLMClient {
        LLMClient()
    }

    public static var previewValue: LLMClient {
        LLMClient()
    }
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var llmClient: LLMClient {
        get { self[LLMClient.self] }
        set { self[LLMClient.self] = newValue }
    }
}
