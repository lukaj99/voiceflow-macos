import Foundation

// MARK: - LLM Provider Implementations

/// Protocol for LLM provider implementations
protocol LLMProviderProtocol {
    func callAPI(prompt: String, apiKey: String, model: LLMModel, maxTokens: Int, temperature: Float) async throws -> String
}

/// OpenAI GPT provider implementation
struct OpenAIProvider: LLMProviderProtocol {
    private let httpClient = URLSession.shared

    func callAPI(prompt: String, apiKey: String, model: LLMModel, maxTokens: Int, temperature: Float) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ProcessingError.apiCallFailed(message: "Invalid OpenAI API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")

        let requestBody = [
            "model": model.rawValue,
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
}

/// Anthropic Claude provider implementation
struct ClaudeProvider: LLMProviderProtocol {
    private let httpClient = URLSession.shared

    func callAPI(prompt: String, apiKey: String, model: LLMModel, maxTokens: Int, temperature: Float) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ProcessingError.apiCallFailed(message: "Invalid Claude API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("VoiceFlow/1.0", forHTTPHeaderField: "User-Agent")

        let requestBody = [
            "model": model.rawValue,
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
}

/// Factory for creating LLM provider instances
struct LLMProviderFactory {
    static func createProvider(for provider: LLMProvider) -> LLMProviderProtocol {
        switch provider {
        case .openAI:
            return OpenAIProvider()
        case .claude:
            return ClaudeProvider()
        }
    }
}
