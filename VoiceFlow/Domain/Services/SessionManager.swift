import Foundation
import Combine
import os.log

/// Service responsible for managing transcription sessions following Single Responsibility Principle
@MainActor
public final class SessionManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var currentSession: TranscriptionSession?
    @Published public private(set) var sessionHistory: [TranscriptionSession] = []
    
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "SessionManager")
    private let storage: SessionStorageProtocol
    
    // Statistics
    @Published public private(set) var sessionDuration: TimeInterval = 0
    @Published public private(set) var wordCount: Int = 0
    @Published public private(set) var averageConfidence: Double = 0
    
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    
    // MARK: - Initialization
    
    public init(storage: SessionStorageProtocol = UserDefaultsSessionStorage()) {
        self.storage = storage
        loadSessionHistory()
    }
    
    // MARK: - Session Management
    
    public func startSession(metadata: TranscriptionSession.Metadata? = nil) {
        guard currentSession == nil else {
            logger.warning("Attempted to start session while one is already active")
            return
        }
        
        sessionStartTime = Date()
        currentSession = TranscriptionSession(
            startTime: sessionStartTime!,
            metadata: metadata ?? TranscriptionSession.Metadata()
        )
        
        startSessionTimer()
        resetStatistics()
        
        logger.info("Started new transcription session: \(self.currentSession!.id)")
    }
    
    public func endSession(finalTranscription: String) async {
        guard var session = currentSession else {
            logger.warning("Attempted to end session but none is active")
            return
        }
        
        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Finalize session
        session.endTime = Date()
        session.duration = sessionDuration
        session.wordCount = wordCount
        session.averageConfidence = averageConfidence
        session.transcription = finalTranscription
        
        // Save session
        await saveSession(session)
        
        // Add to history
        sessionHistory.append(session)
        
        // Clear current session
        currentSession = nil
        resetStatistics()
        
        logger.info("Ended transcription session: \(session.id)")
    }
    
    public func pauseSession() {
        sessionTimer?.invalidate()
        logger.debug("Session paused")
    }
    
    public func resumeSession() {
        startSessionTimer()
        logger.debug("Session resumed")
    }
    
    public func updateSessionTranscription(_ text: String) {
        guard var session = currentSession else { return }
        
        session.transcription = text
        session.wordCount = text.split(separator: " ").count
        
        currentSession = session
        wordCount = session.wordCount
    }
    
    public func updateSessionConfidence(_ confidence: Double) {
        guard var session = currentSession else { return }
        
        // Update running average
        if averageConfidence == 0 {
            averageConfidence = confidence
        } else {
            let updateCount = Double(wordCount + 1)
            averageConfidence = (averageConfidence * Double(wordCount) + confidence) / updateCount
        }
        
        session.averageConfidence = averageConfidence
        currentSession = session
    }
    
    public func addWordTiming(_ timing: TranscriptionUpdate.WordTiming) {
        guard var session = currentSession else { return }
        
        session.wordTimings.append(timing)
        currentSession = session
    }
    
    // MARK: - Session History
    
    public func getSessionHistory(limit: Int? = nil) -> [TranscriptionSession] {
        if let limit = limit {
            return Array(sessionHistory.suffix(limit))
        }
        return sessionHistory
    }
    
    public func deleteSession(_ sessionId: UUID) async {
        // Remove from storage
        await storage.deleteSession(sessionId)
        
        // Remove from history
        sessionHistory.removeAll { $0.id == sessionId }
        
        // If it's the current session, clear it
        if currentSession?.id == sessionId {
            currentSession = nil
            resetStatistics()
        }
        
        logger.info("Deleted session: \(sessionId)")
    }
    
    public func clearSessionHistory() async {
        await storage.clearAllSessions()
        sessionHistory.removeAll()
        logger.info("Cleared all session history")
    }
    
    public func getSession(_ sessionId: UUID) -> TranscriptionSession? {
        return sessionHistory.first { $0.id == sessionId }
    }
    
    // MARK: - Statistics
    
    public func getSessionStatistics() -> SessionStatistics {
        let totalSessions = sessionHistory.count
        let totalDuration = sessionHistory.reduce(0) { $0 + $1.duration }
        let totalWords = sessionHistory.reduce(0) { $0 + $1.wordCount }
        let avgConfidence = sessionHistory.isEmpty ? 0 : 
            sessionHistory.reduce(0) { $0 + $1.averageConfidence } / Double(sessionHistory.count)
        
        return SessionStatistics(
            totalSessions: totalSessions,
            totalDuration: totalDuration,
            totalWords: totalWords,
            averageConfidence: avgConfidence,
            currentSessionDuration: sessionDuration,
            currentWordCount: wordCount
        )
    }
    
    // MARK: - Private Methods
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.sessionStartTime else { return }
            
            self.sessionDuration = Date().timeIntervalSince(startTime)
        }
    }
    
    private func resetStatistics() {
        sessionDuration = 0
        wordCount = 0
        averageConfidence = 0
        sessionStartTime = nil
    }
    
    private func saveSession(_ session: TranscriptionSession) async {
        do {
            await storage.saveSession(session)
            logger.debug("Session saved successfully: \(session.id)")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }
    }
    
    private func loadSessionHistory() {
        Task {
            do {
                sessionHistory = await storage.loadAllSessions()
                logger.info("Loaded \(sessionHistory.count) sessions from storage")
            } catch {
                logger.error("Failed to load session history: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Types

public struct SessionStatistics {
    public let totalSessions: Int
    public let totalDuration: TimeInterval
    public let totalWords: Int
    public let averageConfidence: Double
    public let currentSessionDuration: TimeInterval
    public let currentWordCount: Int
    
    public var averageSessionDuration: TimeInterval {
        totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
    }
    
    public var wordsPerMinute: Double {
        totalDuration > 0 ? Double(totalWords) / (totalDuration / 60.0) : 0
    }
}

// MARK: - Storage Protocol

public protocol SessionStorageProtocol {
    func saveSession(_ session: TranscriptionSession) async throws
    func loadAllSessions() async throws -> [TranscriptionSession]
    func deleteSession(_ sessionId: UUID) async throws
    func clearAllSessions() async throws
}

// MARK: - Default Storage Implementation

public class UserDefaultsSessionStorage: SessionStorageProtocol {
    private let userDefaults = UserDefaults.standard
    private let storageKey = "TranscriptionSessions"
    
    public init() {}
    
    public func saveSession(_ session: TranscriptionSession) async throws {
        var sessions = try await loadAllSessions()
        
        // Replace existing session with same ID or add new one
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(sessions)
        userDefaults.set(data, forKey: storageKey)
    }
    
    public func loadAllSessions() async throws -> [TranscriptionSession] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([TranscriptionSession].self, from: data)
    }
    
    public func deleteSession(_ sessionId: UUID) async throws {
        var sessions = try await loadAllSessions()
        sessions.removeAll { $0.id == sessionId }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(sessions)
        userDefaults.set(data, forKey: storageKey)
    }
    
    public func clearAllSessions() async throws {
        userDefaults.removeObject(forKey: storageKey)
    }
}