import Speech
import Foundation
import Combine
import os.log

/// Processes speech recognition results into transcription updates following Single Responsibility Principle
@MainActor  
public final class TranscriptionProcessor: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "TranscriptionProcessor")
    private let contextProcessor: ContextProcessor
    
    // Statistics tracking
    private var totalWords = 0
    private var totalConfidence: Double = 0
    private var lastUpdateTime: Date = Date()
    
    // Publishers
    private let transcriptionSubject = PassthroughSubject<TranscriptionUpdate, Never>()
    public var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(contextProcessor: ContextProcessor) {
        self.contextProcessor = contextProcessor
    }
    
    // MARK: - Public Methods
    
    public func processRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let now = Date()
        
        // Process the transcription
        let transcription = result.bestTranscription
        let rawText = transcription.formattedString
        
        // Calculate confidence (average of all segments)
        let confidence = calculateConfidence(from: transcription)
        
        // Apply context corrections
        let correctedText = contextProcessor.applyContextCorrections(to: rawText)
        
        // Generate alternatives if available
        let alternatives = generateAlternatives(from: result)
        
        // Extract word timings for final results
        let wordTimings: [TranscriptionUpdate.WordTiming]? = result.isFinal ? 
            extractWordTimings(from: transcription) : nil
        
        // Create update
        let update = TranscriptionUpdate(
            type: result.isFinal ? .final : .partial,
            text: correctedText,
            confidence: confidence,
            alternatives: alternatives,
            wordTimings: wordTimings
        )
        
        // Emit update
        transcriptionSubject.send(update)
        lastUpdateTime = now
        
        // Update statistics for final results
        if result.isFinal {
            updateStatistics(text: correctedText, confidence: confidence)
        }
        
        // Log performance metrics periodically
        logPerformanceMetrics()
    }
    
    public func getStatistics() -> TranscriptionStatistics {
        let avgConfidence = totalWords > 0 ? totalConfidence / Double(totalWords) : 0.0
        return TranscriptionStatistics(
            totalWords: totalWords,
            averageConfidence: avgConfidence,
            lastUpdateTime: lastUpdateTime
        )
    }
    
    public func resetStatistics() {
        totalWords = 0
        totalConfidence = 0
        lastUpdateTime = Date()
    }
    
    // MARK: - Private Methods
    
    private func calculateConfidence(from transcription: SFTranscription) -> Double {
        guard !transcription.segments.isEmpty else { return 0.0 }
        
        let totalConfidence = transcription.segments.reduce(0.0) { sum, segment in
            sum + Double(segment.confidence)
        }
        
        return totalConfidence / Double(transcription.segments.count)
    }
    
    private func generateAlternatives(from result: SFSpeechRecognitionResult) -> [TranscriptionUpdate.Alternative]? {
        let alternatives = result.transcriptions.dropFirst().prefix(2).compactMap { transcription -> TranscriptionUpdate.Alternative? in
            let text = transcription.formattedString
            guard !text.isEmpty else { return nil }
            
            return TranscriptionUpdate.Alternative(
                text: contextProcessor.applyContextCorrections(to: text),
                confidence: calculateConfidence(from: transcription)
            )
        }
        
        return alternatives.isEmpty ? nil : Array(alternatives)
    }
    
    private func extractWordTimings(from transcription: SFTranscription) -> [TranscriptionUpdate.WordTiming] {
        return transcription.segments.map { segment in
            TranscriptionUpdate.WordTiming(
                word: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: Double(segment.confidence)
            )
        }
    }
    
    private func updateStatistics(text: String, confidence: Double) {
        let words = text.split(separator: " ").count
        totalWords += words
        totalConfidence += confidence * Double(words)
    }
    
    private func logPerformanceMetrics() {
        if totalWords % 100 == 0 && totalWords > 0 {
            let avgConfidence = totalConfidence / Double(totalWords)
            logger.info("Transcription stats - Words: \(self.totalWords), Avg confidence: \(avgConfidence)")
        }
    }
}

// MARK: - Supporting Types

public struct TranscriptionStatistics {
    public let totalWords: Int
    public let averageConfidence: Double
    public let lastUpdateTime: Date
    
    public var wordsPerMinute: Double {
        let elapsedMinutes = Date().timeIntervalSince(lastUpdateTime) / 60.0
        return elapsedMinutes > 0 ? Double(totalWords) / elapsedMinutes : 0.0
    }
}