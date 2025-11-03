import Foundation
import Combine

/// LLM-powered post-processing service for transcription enhancement
/// Supports OpenAI GPT and Anthropic Claude APIs for grammar correction, punctuation, and word substitution
@MainActor
public class LLMPostProcessingService: ObservableObject {

    // MARK: - Published Properties

    @Published public var isProcessing = false
    @Published public var processingProgress: Float = 0.0
    @Published public var lastError: ProcessingError?
    @Published public var processingStats = LLMProcessingStatistics()

    // MARK: - Configuration

    public var selectedModel: LLMModel = .gpt4oMini
    public var isEnabled = false
    public var maxTokens: Int = 1000
    public var temperature: Float = 0.1 // Low temperature for consistent corrections
    public var useContextualCorrection = true
    public var enableWordSubstitution = true

    // MARK: - Private Properties

    private var apiKeys: [LLMProvider: String] = [:]
    private let cacheManager: LLMCacheManager
    private var processingQueue: DispatchQueue

    // MARK: - Initialization

    public init() {
        self.cacheManager = LLMCacheManager(maxSize: 100)
        self.processingQueue = DispatchQueue(label: "com.voiceflow.llm-processing", qos: .userInitiated)
        print("🤖 LLM Post-Processing Service initialized")
    }

    // MARK: - Configuration Methods

    /// Configure API key for a specific LLM provider.
    ///
    /// Stores the API key for authentication with OpenAI or Anthropic Claude services.
    /// Keys are held in memory during app runtime.
    ///
    /// ## Usage Example
    /// ```swift
    /// let service = LLMPostProcessingService()
    /// service.configureAPIKey("sk-...", for: .openAI)
    /// service.configureAPIKey("sk-ant-...", for: .claude)
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - provider: The LLM provider (OpenAI or Claude)
    ///
    /// - Note: Keys should be stored securely in Keychain for persistence
    /// - SeeAlso: `isConfigured(for:)`, `LLMProvider`
    public func configureAPIKey(_ apiKey: String, for provider: LLMProvider) {
        apiKeys[provider] = apiKey
        print("🔑 API key configured for \(provider.displayName)")
    }

    /// Check if provider is configured with API key.
    ///
    /// Returns whether an API key has been set for the specified provider.
    ///
    /// ## Usage Example
    /// ```swift
    /// if service.isConfigured(for: .openAI) {
    ///     // OpenAI is ready to use
    /// }
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter provider: The LLM provider to check
    /// - Returns: true if API key is configured, false otherwise
    /// - SeeAlso: `configureAPIKey(_:for:)`, `getAvailableModels()`
    public func isConfigured(for provider: LLMProvider) -> Bool {
        return apiKeys[provider] != nil
    }

    /// Get available models based on configured providers.
    ///
    /// Returns a list of LLM models that can be used, filtered by which providers
    /// have been configured with API keys.
    ///
    /// ## Usage Example
    /// ```swift
    /// let models = service.getAvailableModels()
    /// for model in models {
    ///     print("\(model.displayName) - \(model.provider.displayName)")
    /// }
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(n) where n = total model count (4)
    /// - Memory usage: O(m) where m = configured model count
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Returns: Array of available LLM models
    /// - SeeAlso: `isConfigured(for:)`, `LLMModel`, `selectedModel`
    public func getAvailableModels() -> [LLMModel] {
        return LLMModel.allCases.filter { model in
            isConfigured(for: model.provider)
        }
    }

    // MARK: - Processing Methods

    /// Process transcription text with LLM enhancement.
    ///
    /// Applies AI-powered post-processing to improve transcription quality through:
    /// - Grammar and punctuation correction
    /// - Capitalization fixes
    /// - Word substitution (e.g., "slash" → "/", "at sign" → "@")
    /// - Natural language enhancement
    ///
    /// Results are cached for efficiency. Processing includes progress tracking
    /// and comprehensive error handling.
    ///
    /// ## Usage Example
    /// ```swift
    /// let result = await service.processTranscription(
    ///     "hello world this is a test slash example",
    ///     context: "technical documentation"
    /// )
    ///
    /// switch result {
    /// case .success(let processed):
    ///     print("Original: \(processed.originalText)")
    ///     print("Enhanced: \(processed.processedText)")
    ///     print("Changes: \(processed.changes.count)")
    /// case .failure(let error):
    ///     print("Error: \(error.localizedDescription)")
    /// }
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(n) where n = text length + LLM API latency
    /// - Memory usage: O(n) for text processing
    /// - Thread-safe: Yes (MainActor isolated)
    /// - Typical latency: 500ms - 2s depending on model
    ///
    /// - Parameters:
    ///   - text: The transcription text to process
    ///   - context: Optional context to guide processing (e.g., "medical", "technical")
    ///
    /// - Returns: Result containing ProcessingResult on success or ProcessingError on failure
    /// - Note: Results are cached; identical requests return cached results
    /// - SeeAlso: `ProcessingResult`, `ProcessingError`, `selectedModel`
    public func processTranscription(
        _ text: String,
        context: String? = nil
    ) async -> Result<ProcessingResult, ProcessingError> {
        guard isEnabled else {
            return .failure(.modelUnavailable)
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.textTooLong)
        }

        // Check cache first
        let cacheKey = cacheManager.generateKey(text: text, model: selectedModel)
        if let cachedResult = cacheManager.get(key: cacheKey) {
            print("📋 Using cached result for text processing")
            return .success(cachedResult)
        }

        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
            lastError = nil
        }

        do {
            let result = try await performProcessing(text: text, context: context)

            // Cache the result
            await MainActor.run {
                cacheManager.set(key: cacheKey, result: result)

                // Update statistics
                processingStats.totalProcessed += 1
                processingStats.totalProcessingTime += result.processingTime
                processingStats.averageProcessingTime = processingStats.totalProcessingTime
                    / Double(processingStats.totalProcessed)

                if result.improvementScore > 0.5 {
                    processingStats.successfulProcessings += 1
                }

                isProcessing = false
                processingProgress = 1.0
            }

            print("✅ LLM processing completed in \(result.processingTime)s")
            return .success(result)

        } catch {
            let processingError = error as? ProcessingError ?? .networkError(error.localizedDescription)

            await MainActor.run {
                lastError = processingError
                isProcessing = false
                processingProgress = 0.0
                processingStats.failedProcessings += 1
            }

            print("❌ LLM processing failed: \(processingError.localizedDescription)")
            return .failure(processingError)
        }
    }

    /// Process text with the selected model
    private func performProcessing(text: String, context: String?) async throws -> ProcessingResult {
        let startTime = Date()

        guard let apiKey = apiKeys[selectedModel.provider] else {
            throw ProcessingError.apiKeyMissing
        }

        await MainActor.run {
            processingProgress = 0.3
        }

        let prompt = buildPrompt(text: text, context: context)

        await MainActor.run {
            processingProgress = 0.5
        }

        let provider = LLMProviderFactory.createProvider(for: selectedModel.provider)
        let response = try await provider.callAPI(
            prompt: prompt,
            apiKey: apiKey,
            model: selectedModel,
            maxTokens: maxTokens,
            temperature: temperature
        )

        await MainActor.run {
            processingProgress = 0.8
        }

        let result = parseResponse(response, originalText: text, startTime: startTime)

        await MainActor.run {
            processingProgress = 1.0
        }

        return result
    }

    /// Build the prompt for LLM processing
    private func buildPrompt(text: String, context: String?) -> String {
        var prompt = """
        You are a professional transcription editor. Your task is to improve the accuracy and \
        readability of speech-to-text transcriptions while maintaining the original meaning and style.

        Please:
        1. Correct grammar and punctuation errors
        2. Fix capitalization issues
        3. Replace spoken symbols with actual symbols (e.g., "slash" → "/", "at sign" → "@")
        4. Maintain the speaker's natural language style
        5. Do not add content that wasn't spoken
        6. Keep corrections minimal and natural

        """

        if let context = context {
            prompt += "Context: \(context)\n\n"
        }

        if enableWordSubstitution {
            prompt += "Common word substitutions to apply:\n"
            for (spoken, symbol) in WordSubstitutions.mappings {
                prompt += "- \"\(spoken)\" → \"\(symbol)\"\n"
            }
            prompt += "\n"
        }

        prompt += """
        Original transcription:
        "\(text)"

        Please provide the corrected version. Return only the corrected text without \
        explanations or additional formatting.
        """

        return prompt
    }

    /// Parse the LLM response and create a processing result
    private func parseResponse(_ response: String, originalText: String, startTime: Date) -> ProcessingResult {
        let processingTime = Date().timeIntervalSince(startTime)

        // Analyze changes made
        let changes = analyzeChanges(original: originalText, processed: response)

        // Calculate improvement score based on changes
        let improvementScore = calculateImprovementScore(changes: changes)

        return ProcessingResult(
            originalText: originalText,
            processedText: response,
            improvementScore: improvementScore,
            processingTime: processingTime,
            model: selectedModel,
            changes: changes
        )
    }

    /// Analyze changes between original and processed text
    private func analyzeChanges(original: String, processed: String) -> [TextChange] {
        var changes: [TextChange] = []

        // Simple word substitution detection
        for (spoken, symbol) in WordSubstitutions.mappings {
            if original.localizedCaseInsensitiveContains(spoken) && processed.contains(symbol) {
                changes.append(TextChange(
                    type: .wordSubstitution,
                    original: spoken,
                    replacement: symbol,
                    reason: "Converted spoken symbol to actual symbol"
                ))
            }
        }

        // Basic punctuation and capitalization analysis
        if original.filter({ $0.isPunctuation }).count < processed.filter({ $0.isPunctuation }).count {
            changes.append(TextChange(
                type: .punctuation,
                original: "missing punctuation",
                replacement: "added punctuation",
                reason: "Added missing punctuation"
            ))
        }

        return changes
    }

    /// Calculate improvement score based on changes
    private func calculateImprovementScore(changes: [TextChange]) -> Float {
        if changes.isEmpty {
            return 0.0
        }

        let scorePerChange: Float = 0.1
        return min(1.0, Float(changes.count) * scorePerChange)
    }

    /// Clear processing cache to free memory.
    ///
    /// Removes all cached processing results. Useful for:
    /// - Freeing memory
    /// - Ensuring fresh processing after configuration changes
    /// - Testing and debugging
    ///
    /// ## Usage Example
    /// ```swift
    /// service.clearCache()
    /// // All cached results removed
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: Frees O(n) where n = cache size
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - SeeAlso: `processTranscription(_:context:)`
    public func clearCache() {
        cacheManager.clear()
    }

    /// Get processing statistics for monitoring and analytics.
    ///
    /// Returns cumulative statistics about LLM processing performance including:
    /// - Total processed count
    /// - Success and failure counts
    /// - Average processing time
    /// - Success rate
    ///
    /// ## Usage Example
    /// ```swift
    /// let stats = service.getStatistics()
    /// print("Processed: \(stats.totalProcessed)")
    /// print("Success rate: \(stats.successRate * 100)%")
    /// print("Avg time: \(stats.averageProcessingTime)s")
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Returns: Processing statistics snapshot
    /// - SeeAlso: `LLMProcessingStatistics`, `processingStats`
    public func getStatistics() -> LLMProcessingStatistics {
        return processingStats
    }
}
