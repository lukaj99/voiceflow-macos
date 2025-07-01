import Foundation
import Combine

/// Service for storing and managing transcription sessions
@MainActor
public final class SessionStorageService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var sessions: [StoredTranscriptionSession] = []
    @Published public private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var sessionsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voiceFlowDir = appSupport.appendingPathComponent("VoiceFlow")
        let sessionsDir = voiceFlowDir.appendingPathComponent("Sessions")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        
        return sessionsDir
    }
    
    // MARK: - Initialization
    
    public init() {
        setupEncoder()
        Task {
            await loadSessions()
        }
    }
    
    // MARK: - Public Methods
    
    public func saveSession(_ session: TranscriptionSession) async throws {
        let storedSession = StoredTranscriptionSession(
            id: session.id,
            startTime: session.startTime,
            endTime: session.endTime ?? Date(),
            duration: session.duration,
            transcription: session.transcription,
            wordCount: session.wordCount,
            averageConfidence: session.averageConfidence,
            language: session.metadata.language,
            contextType: session.metadata.contextType,
            privacy: session.metadata.privacy
        )
        
        let filename = "\(session.id.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(storedSession)
        try data.write(to: fileURL)
        
        // Add to memory cache
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = storedSession
        } else {
            sessions.append(storedSession)
            sessions.sort { $0.startTime > $1.startTime } // Most recent first
        }
    }
    
    public func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }
            
            var loadedSessions: [StoredTranscriptionSession] = []
            
            for fileURL in fileURLs {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let session = try decoder.decode(StoredTranscriptionSession.self, from: data)
                    loadedSessions.append(session)
                } catch {
                    print("Failed to load session from \(fileURL): \(error)")
                    // Optionally delete corrupted files
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            
            // Sort by start time (most recent first)
            sessions = loadedSessions.sorted { $0.startTime > $1.startTime }
            
        } catch {
            print("Failed to load sessions directory: \(error)")
        }
    }
    
    public func deleteSession(_ sessionId: UUID) async throws {
        let filename = "\(sessionId.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(filename)
        
        // Remove from file system
        try fileManager.removeItem(at: fileURL)
        
        // Remove from memory cache
        sessions.removeAll { $0.id == sessionId }
    }
    
    public func deleteAllSessions() async throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        
        for fileURL in fileURLs {
            try fileManager.removeItem(at: fileURL)
        }
        
        sessions.removeAll()
    }
    
    public func getSession(_ sessionId: UUID) -> StoredTranscriptionSession? {
        return sessions.first { $0.id == sessionId }
    }
    
    public func searchSessions(query: String) -> [StoredTranscriptionSession] {
        guard !query.isEmpty else { return sessions }
        
        let lowercaseQuery = query.lowercased()
        return sessions.filter {
            $0.transcription.lowercased().contains(lowercaseQuery)
        }
    }
    
    public func getSessionsCount() -> Int {
        return sessions.count
    }
    
    public func getTotalDuration() -> TimeInterval {
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    public func getTotalWordCount() -> Int {
        return sessions.reduce(0) { $0 + $1.wordCount }
    }
    
    public func getSessionsInDateRange(from startDate: Date, to endDate: Date) -> [StoredTranscriptionSession] {
        return sessions.filter { session in
            session.startTime >= startDate && session.startTime <= endDate
        }
    }
    
    // MARK: - Data Retention
    
    public func cleanupOldSessions(olderThan days: Int) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let sessionsToDelete = sessions.filter { $0.startTime < cutoffDate }
        
        for session in sessionsToDelete {
            try await deleteSession(session.id)
        }
    }
    
    public func exportSessionsAsJSON() throws -> Data {
        return try encoder.encode(sessions)
    }
    
    public func importSessionsFromJSON(_ data: Data) async throws {
        let importedSessions = try decoder.decode([StoredTranscriptionSession].self, from: data)
        
        // Save each session
        for session in importedSessions {
            let filename = "\(session.id.uuidString).json"
            let fileURL = sessionsDirectory.appendingPathComponent(filename)
            
            let sessionData = try encoder.encode(session)
            try sessionData.write(to: fileURL)
        }
        
        // Reload sessions
        await loadSessions()
    }
    
    // MARK: - Private Methods
    
    private func setupEncoder() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        decoder.dateDecodingStrategy = .iso8601
    }
}

// MARK: - Supporting Types

public struct StoredTranscriptionSession: Codable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let transcription: String
    public let wordCount: Int
    public let averageConfidence: Double
    public let language: String
    public let contextType: String
    public let privacy: String
    
    // Computed properties
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    public var preview: String {
        let maxLength = 100
        if transcription.count <= maxLength {
            return transcription
        } else {
            let endIndex = transcription.index(transcription.startIndex, offsetBy: maxLength)
            return String(transcription[..<endIndex]) + "..."
        }
    }
}

// MARK: - Statistics

extension SessionStorageService {
    public struct SessionStatistics {
        public let totalSessions: Int
        public let totalDuration: TimeInterval
        public let totalWords: Int
        public let averageSessionDuration: TimeInterval
        public let averageWordsPerMinute: Double
        public let averageConfidence: Double
        public let mostActiveDay: Date?
        public let longestSession: StoredTranscriptionSession?
        public let mostProductiveSession: StoredTranscriptionSession?
    }
    
    public func getStatistics() -> SessionStatistics {
        guard !sessions.isEmpty else {
            return SessionStatistics(
                totalSessions: 0,
                totalDuration: 0,
                totalWords: 0,
                averageSessionDuration: 0,
                averageWordsPerMinute: 0,
                averageConfidence: 0,
                mostActiveDay: nil,
                longestSession: nil,
                mostProductiveSession: nil
            )
        }
        
        let totalDuration = getTotalDuration()
        let totalWords = getTotalWordCount()
        let averageSessionDuration = totalDuration / Double(sessions.count)
        let averageWordsPerMinute = totalDuration > 0 ? (Double(totalWords) / totalDuration) * 60 : 0
        let averageConfidence = sessions.reduce(0) { $0 + $1.averageConfidence } / Double(sessions.count)
        
        // Find most active day
        let calendar = Calendar.current
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        let mostActiveDay = sessionsByDay.max { $0.value.count < $1.value.count }?.key
        
        // Find longest and most productive sessions
        let longestSession = sessions.max { $0.duration < $1.duration }
        let mostProductiveSession = sessions.max { $0.wordCount < $1.wordCount }
        
        return SessionStatistics(
            totalSessions: sessions.count,
            totalDuration: totalDuration,
            totalWords: totalWords,
            averageSessionDuration: averageSessionDuration,
            averageWordsPerMinute: averageWordsPerMinute,
            averageConfidence: averageConfidence,
            mostActiveDay: mostActiveDay,
            longestSession: longestSession,
            mostProductiveSession: mostProductiveSession
        )
    }
}