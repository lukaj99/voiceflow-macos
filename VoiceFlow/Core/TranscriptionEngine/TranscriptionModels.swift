import Foundation
import Combine

// MARK: - Transcription Update Types

public struct TranscriptionUpdate: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: UpdateType
    public let text: String
    public let confidence: Double
    public let alternatives: [Alternative]?
    public let wordTimings: [WordTiming]?
    
    public enum UpdateType: String, Codable, Sendable {
        case partial
        case final
        case correction
    }
    
    public struct Alternative: Codable, Sendable {
        public let text: String
        public let confidence: Double
        
        public init(text: String, confidence: Double) {
            self.text = text
            self.confidence = confidence
        }
    }
    
    public struct WordTiming: Codable, Sendable {
        public let word: String
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public let confidence: Double
        
        public init(word: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double) {
            self.word = word
            self.startTime = startTime
            self.endTime = endTime
            self.confidence = confidence
        }
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: UpdateType,
        text: String,
        confidence: Double,
        alternatives: [Alternative]? = nil,
        wordTimings: [WordTiming]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.text = text
        self.confidence = confidence
        self.alternatives = alternatives
        self.wordTimings = wordTimings
    }
}

// MARK: - Context Models

public enum AppContext: Equatable, Sendable {
    case general
    case coding(language: CodingLanguage?)
    case email(tone: EmailTone)
    case chat(formality: Formality)
    case meeting
    case notes
    case document(type: DocumentType)
    
    public enum CodingLanguage: String, CaseIterable, Sendable {
        case swift, python, javascript, java, go, rust, cpp, csharp
    }
    
    public enum EmailTone: String, CaseIterable, Sendable {
        case professional, casual, formal
    }
    
    public enum Formality: String, CaseIterable, Sendable {
        case casual, business, formal
    }
    
    public enum DocumentType: String, CaseIterable, Sendable {
        case formal, creative, technical, academic
    }
}

// MARK: - Storage Models

/// Represents a transcription segment with timing information
public struct TranscriptionSegment: Codable, Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    
    public var duration: TimeInterval {
        endTime - startTime
    }
    
    public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

// MARK: - Language Support

public enum Language: String, CaseIterable, Codable, Sendable {
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case chinese = "zh-CN"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case russian = "ru-RU"
    case arabic = "ar-SA"
    case hindi = "hi-IN"
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .russian: return "Russian"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }
    
    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}

public struct TranscriptionSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval
    public let wordCount: Int
    public let averageConfidence: Double
    public let context: String // Serialized AppContext
    public let transcription: String
    public let metadata: Metadata
    public let segments: [TranscriptionSegment]
    public let createdAt: Date
    public let language: Language
    
    public struct Metadata: Codable, Sendable {
        public let appName: String?
        public let appBundleID: String?
        public let customVocabularyHits: Int
        public let correctionsApplied: Int
        public let privacyMode: PrivacyMode
        public let title: String?
        public let tags: [String]
        public let language: String?
        public let contextType: String?
        public let privacy: String?
        public let speaker: String?
        public let location: String?
        
        public init(
            appName: String? = nil,
            appBundleID: String? = nil,
            customVocabularyHits: Int = 0,
            correctionsApplied: Int = 0,
            privacyMode: PrivacyMode = .balanced,
            title: String? = nil,
            tags: [String] = [],
            language: String? = nil,
            contextType: String? = nil,
            privacy: String? = nil,
            speaker: String? = nil,
            location: String? = nil
        ) {
            self.appName = appName
            self.appBundleID = appBundleID
            self.customVocabularyHits = customVocabularyHits
            self.correctionsApplied = correctionsApplied
            self.privacyMode = privacyMode
            self.title = title
            self.tags = tags
            self.language = language
            self.contextType = contextType
            self.privacy = privacy
            self.speaker = speaker
            self.location = location
        }
    }
    
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval = 0,
        wordCount: Int = 0,
        averageConfidence: Double = 0,
        context: String = "general",
        transcription: String = "",
        metadata: Metadata = Metadata(),
        segments: [TranscriptionSegment] = [],
        createdAt: Date = Date(),
        language: Language = .english
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.wordCount = wordCount
        self.averageConfidence = averageConfidence
        self.context = context
        self.transcription = transcription
        self.metadata = metadata
        self.segments = segments
        self.createdAt = createdAt
        self.language = language
    }
}

// MARK: - Privacy Models

public enum PrivacyMode: String, Codable, CaseIterable, Sendable {
    case maximum = "maximum"      // No telemetry, no sync
    case balanced = "balanced"     // Anonymous telemetry only
    case convenience = "convenience" // Full features with encryption
    
    public var description: String {
        switch self {
        case .maximum:
            return "Maximum Privacy - No data leaves your device"
        case .balanced:
            return "Balanced - Anonymous usage data only"
        case .convenience:
            return "Convenience - Full features with encryption"
        }
    }
}

// MARK: - Transcription Engine Protocol

@MainActor
public protocol TranscriptionEngineProtocol: Sendable {
    var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> { get }
    
    func startTranscription() async throws
    func stopTranscription() async
    func pauseTranscription() async
    func resumeTranscription() async
    
    func setLanguage(_ language: String) async
    func setContext(_ context: AppContext) async
    func addCustomVocabulary(_ words: [String]) async
}

// MARK: - Performance Metrics

public struct TranscriptionMetrics: Sendable {
    public let latency: TimeInterval
    public let confidence: Double
    public let wordCount: Int
    public let processingTime: TimeInterval
    
    public init(
        latency: TimeInterval,
        confidence: Double,
        wordCount: Int,
        processingTime: TimeInterval
    ) {
        self.latency = latency
        self.confidence = confidence
        self.wordCount = wordCount
        self.processingTime = processingTime
    }
}

// MARK: - Audio Processing
// Note: AudioProcessingActor is now implemented in AudioManager.swift
// with proper Swift 6 actor isolation patterns

// MARK: - Extensions

extension TimeInterval {
    public var humanReadable: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}