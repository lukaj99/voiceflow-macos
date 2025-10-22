import Foundation
import Combine

/// LLM-powered post-processing service for transcription enhancement
/// Supports OpenAI GPT and Anthropic Claude APIs for grammar correction, punctuation, and word substitution
@MainActor
public class LLMPostProcessingService: ObservableObject {
    
    // MARK: - Types
    
    public enum LLMProvider: String, CaseIterable {
        case openAI = "openai"
        case claude = "claude"
        
        public var displayName: String {
            switch self {
            case .openAI: return "OpenAI GPT"
            case .claude: return "Anthropic Claude"
            }
        }
        
        public var models: [LLMModel] {
            switch self {
            case .openAI: return [.gpt4oMini, .gpt4o]
            case .claude: return [.claudeHaiku, .claudeSonnet]
            }
        }
    }
    
    public enum LLMModel: String, CaseIterable, Sendable {
        case gpt4oMini = "gpt-4o-mini"
        case gpt4o = "gpt-4o"
        case claudeHaiku = "claude-3-haiku-20240307"
        case claudeSonnet = "claude-3-sonnet-20240229"
        
        public var displayName: String {
            switch self {
            case .gpt4oMini: return "GPT-4o Mini"
            case .gpt4o: return "GPT-4o"
            case .claudeHaiku: return "Claude 3 Haiku"
            case .claudeSonnet: return "Claude 3 Sonnet"
            }
        }
        
        public var provider: LLMProvider {
            switch self {
            case .gpt4oMini, .gpt4o: return .openAI
            case .claudeHaiku, .claudeSonnet: return .claude
            }
        }
        
        public var isRecommended: Bool {
            return self == .gpt4oMini || self == .claudeHaiku
        }
    }
    
    public struct ProcessingResult: Sendable {
        public let originalText: String
        public let processedText: String
        public let improvementScore: Float
        public let processingTime: TimeInterval
        public let model: LLMModel
        public let changes: [TextChange]
        
        public struct TextChange: Sendable {
            public let type: ChangeType
            public let original: String
            public let replacement: String
            public let reason: String
            
            public enum ChangeType: Sendable {
                case grammar
                case punctuation
                case wordSubstitution
                case capitalization
                case formatting
            }
        }
    }
    
    public enum ProcessingError: Error, LocalizedError {
        case apiKeyMissing
        case apiKeyInvalid
        case networkError(String)
        case invalidResponse
        case rateLimitExceeded
        case textTooLong
        case modelUnavailable
        
        public var errorDescription: String? {
            switch self {
            case .apiKeyMissing:
                return "LLM API key is missing. Please configure it in Settings."
            case .apiKeyInvalid:
                return "LLM API key is invalid. Please check your credentials."
            case .networkError(let message):
                return "Network error: \(message)"
            case .invalidResponse:
                return "Invalid response from LLM service"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
            case .textTooLong:
                return "Text is too long for processing"
            case .modelUnavailable:
                return "Selected LLM model is currently unavailable"
            }
        }
    }
    
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
    private let httpClient = URLSession.shared
    private var processingQueue: DispatchQueue
    private var requestCache: [String: ProcessingResult] = [:]
    private let maxCacheSize = 100
    
    // Word substitution rules
    private let wordSubstitutions: [String: String] = [
        "slash": "/",
        "backslash": "\\",
        "at sign": "@",
        "hashtag": "#",
        "dollar sign": "$",
        "percent": "%",
        "ampersand": "&",
        "asterisk": "*",
        "plus": "+",
        "equals": "=",
        "dash": "-",
        "underscore": "_",
        "pipe": "|",
        "tilde": "~",
        "caret": "^",
        "question mark": "?",
        "exclamation mark": "!",
        "period": ".",
        "comma": ",",
        "semicolon": ";",
        "colon": ":",
        "open parenthesis": "(",
        "close parenthesis": ")",
        "open bracket": "[",
        "close bracket": "]",
        "open brace": "{",
        "close brace": "}",
        "less than": "<",
        "greater than": ">",
        "quote": "\"",
        "single quote": "'",
        "backtick": "`"
    ]
    
    // MARK: - Initialization
    
    public init() {
        self.processingQueue = DispatchQueue(label: "com.voiceflow.llm-processing", qos: .userInitiated)
        print("🤖 LLM Post-Processing Service initialized")
    }
    
    // MARK: - Configuration Methods
    
    /// Configure API key for a specific provider
    public func configureAPIKey(_ apiKey: String, for provider: LLMProvider) {
        apiKeys[provider] = apiKey
        print("🔑 API key configured for \(provider.displayName)")
    }
    
    /// Check if provider is configured
    public func isConfigured(for provider: LLMProvider) -> Bool {
        return apiKeys[provider] != nil
    }
    
    /// Get available models based on configured providers
    public func getAvailableModels() -> [LLMModel] {
        return LLMModel.allCases.filter { model in
            isConfigured(for: model.provider)
        }
    }
    
    // MARK: - Processing Methods
    
    /// Process transcription text with LLM enhancement
    public func processTranscription(_ text: String, context: String? = nil) async -> Result<ProcessingResult, ProcessingError> {
        guard isEnabled else {
            return .failure(.modelUnavailable)
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.textTooLong)
        }
        
        // Check cache first
        let cacheKey = generateCacheKey(text: text, model: selectedModel)
        if let cachedResult = requestCache[cacheKey] {
            print("📋 Using cached result for text processing")
            return .success(cachedResult)
        }
        
        // Removed unused startTime
        
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
            lastError = nil
        }
        
        do {
            let result = try await performProcessing(text: text, context: context)
            
            // Cache the result
            await MainActor.run {
                requestCache[cacheKey] = result
                if requestCache.count > maxCacheSize {
                    requestCache.removeValue(forKey: requestCache.keys.first!)
                }
                
                // Update statistics
                processingStats.totalProcessed += 1
                processingStats.totalProcessingTime += result.processingTime
                processingStats.averageProcessingTime = processingStats.totalProcessingTime / Double(processingStats.totalProcessed)
                
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
        
        let response = try await callLLMAPI(prompt: prompt, apiKey: apiKey)
        
        await MainActor.run {
            processingProgress = 0.8
        }
        
        let result = try parseResponse(response, originalText: text, startTime: startTime)
        
        await MainActor.run {
            processingProgress = 1.0
        }
        
        return result
    }
    
    /// Build the prompt for LLM processing
    private func buildPrompt(text: String, context: String?) -> String {
        var prompt = """
        You are a professional transcription editor. Your task is to improve the accuracy and readability of speech-to-text transcriptions while maintaining the original meaning and style.
        
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
            for (spoken, symbol) in wordSubstitutions {
                prompt += "- \"\(spoken)\" → \"\(symbol)\"\n"
            }
            prompt += "\n"
        }
        
        prompt += """
        Original transcription:
        "\(text)"
        
        Please provide the corrected version. Return only the corrected text without explanations or additional formatting.
        """
        
        return prompt
    }
    
    /// Call the appropriate LLM API
    private func callLLMAPI(prompt: String, apiKey: String) async throws -> String {
        switch selectedModel.provider {
        case .openAI:
            return try await callOpenAIAPI(prompt: prompt, apiKey: apiKey)
        case .claude:
            return try await callClaudeAPI(prompt: prompt, apiKey: apiKey)
        }
    }
    
    /// Call OpenAI API
    private func callOpenAIAPI(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")
        
        let requestBody = [
            "model": selectedModel.rawValue,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
            "presence_penalty": 0.1,
            "frequency_penalty": 0.1
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await httpClient.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ProcessingError.apiKeyInvalid
        case 429:
            throw ProcessingError.rateLimitExceeded
        default:
            throw ProcessingError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProcessingError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Call Claude API
    private func callClaudeAPI(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")
        
        let requestBody = [
            "model": selectedModel.rawValue,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await httpClient.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProcessingError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ProcessingError.apiKeyInvalid
        case 429:
            throw ProcessingError.rateLimitExceeded
        default:
            throw ProcessingError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ProcessingError.invalidResponse
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Parse the LLM response and create a processing result
    private func parseResponse(_ response: String, originalText: String, startTime: Date) throws -> ProcessingResult {
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
    private func analyzeChanges(original: String, processed: String) -> [ProcessingResult.TextChange] {
        var changes: [ProcessingResult.TextChange] = []
        
        // Simple word substitution detection
        for (spoken, symbol) in wordSubstitutions {
            if original.localizedCaseInsensitiveContains(spoken) && processed.contains(symbol) {
                changes.append(ProcessingResult.TextChange(
                    type: .wordSubstitution,
                    original: spoken,
                    replacement: symbol,
                    reason: "Converted spoken symbol to actual symbol"
                ))
            }
        }
        
        // Basic punctuation and capitalization analysis
        if original.filter({ $0.isPunctuation }).count < processed.filter({ $0.isPunctuation }).count {
            changes.append(ProcessingResult.TextChange(
                type: .punctuation,
                original: "missing punctuation",
                replacement: "added punctuation",
                reason: "Added missing punctuation"
            ))
        }
        
        return changes
    }
    
    /// Calculate improvement score based on changes
    private func calculateImprovementScore(changes: [ProcessingResult.TextChange]) -> Float {
        if changes.isEmpty {
            return 0.0
        }
        
        let scorePerChange: Float = 0.1
        return min(1.0, Float(changes.count) * scorePerChange)
    }
    
    /// Generate cache key for request
    private func generateCacheKey(text: String, model: LLMModel) -> String {
        let textHash = text.hash
        return "\(model.rawValue)_\(textHash)"
    }
    
    /// Clear processing cache
    public func clearCache() {
        requestCache.removeAll()
        print("🧹 LLM processing cache cleared")
    }
    
    /// Get processing statistics
    public func getStatistics() -> LLMProcessingStatistics {
        return processingStats
    }
}

// MARK: - Supporting Types

public struct LLMProcessingStatistics: Sendable {
    public var totalProcessed: Int = 0
    public var successfulProcessings: Int = 0
    public var failedProcessings: Int = 0
    public var totalProcessingTime: TimeInterval = 0
    public var averageProcessingTime: TimeInterval = 0
    
    public var successRate: Float {
        guard totalProcessed > 0 else { return 0.0 }
        return Float(successfulProcessings) / Float(totalProcessed)
    }
    
    public mutating func recordProcessing(success: Bool, processingTime: TimeInterval, improvementScore: Float = 0.0) {
        totalProcessed += 1
        totalProcessingTime += processingTime
        averageProcessingTime = totalProcessingTime / Double(totalProcessed)
        
        if success {
            successfulProcessings += 1
        } else {
            failedProcessings += 1
        }
    }
} 