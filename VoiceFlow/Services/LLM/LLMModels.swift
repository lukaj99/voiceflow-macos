import Foundation

// MARK: - LLM Models and Configuration Types

/// Supported LLM providers for post-processing
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

/// Available LLM models for transcription enhancement
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

/// Result of LLM post-processing operation
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

/// Errors that can occur during LLM processing
public enum ProcessingError: Error, LocalizedError {
    case apiKeyMissing
    case apiKeyInvalid
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case textTooLong
    case modelUnavailable
    case apiCallFailed(message: String)

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
        case .apiCallFailed(let message):
            return "API call failed: \(message)"
        }
    }
}

/// Statistics for LLM processing performance monitoring
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

/// Word substitution mappings for spoken symbols
public struct WordSubstitutions {
    public static let mappings: [String: String] = [
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
}
