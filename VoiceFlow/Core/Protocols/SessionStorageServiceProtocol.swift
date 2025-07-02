import Foundation
import Combine

/// Protocol defining the interface for storing and managing transcription sessions
@MainActor
public protocol SessionStorageServiceProtocol: AnyObject, ObservableObject, Sendable {
    
    // MARK: - Properties
    
    var sessions: [StoredTranscriptionSession] { get }
    var isLoading: Bool { get }
    
    // MARK: - Session Management
    
    func saveSession(_ session: TranscriptionSession) async throws
    func loadSessions() async
    func deleteSession(_ sessionId: UUID) async throws
    func deleteAllSessions() async throws
    func getSession(_ sessionId: UUID) -> StoredTranscriptionSession?
    
    // MARK: - Search and Query
    
    func searchSessions(query: String) -> [StoredTranscriptionSession]
    func getSessionsInDateRange(from startDate: Date, to endDate: Date) -> [StoredTranscriptionSession]
    
    // MARK: - Statistics
    
    func getSessionsCount() -> Int
    func getTotalDuration() -> TimeInterval
    func getTotalWordCount() -> Int
    func getStatistics() -> SessionStatistics
    
    // MARK: - Data Management
    
    func cleanupOldSessions(olderThan days: Int) async throws
    func exportSessionsAsJSON() throws -> Data
    func importSessionsFromJSON(_ data: Data) async throws
}

// MARK: - Session Statistics Type

public struct SessionStatistics: Sendable {
    public let totalSessions: Int
    public let totalDuration: TimeInterval
    public let totalWords: Int
    public let averageSessionDuration: TimeInterval
    public let averageWordsPerMinute: Double
    public let averageConfidence: Double
    public let mostActiveDay: Date?
    public let longestSession: StoredTranscriptionSession?
    public let mostProductiveSession: StoredTranscriptionSession?
    
    public init(
        totalSessions: Int,
        totalDuration: TimeInterval,
        totalWords: Int,
        averageSessionDuration: TimeInterval,
        averageWordsPerMinute: Double,
        averageConfidence: Double,
        mostActiveDay: Date?,
        longestSession: StoredTranscriptionSession?,
        mostProductiveSession: StoredTranscriptionSession?
    ) {
        self.totalSessions = totalSessions
        self.totalDuration = totalDuration
        self.totalWords = totalWords
        self.averageSessionDuration = averageSessionDuration
        self.averageWordsPerMinute = averageWordsPerMinute
        self.averageConfidence = averageConfidence
        self.mostActiveDay = mostActiveDay
        self.longestSession = longestSession
        self.mostProductiveSession = mostProductiveSession
    }
}