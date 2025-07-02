//
//  MockSettingsService.swift
//  VoiceFlowTests
//
//  Mock implementation of settings service for testing
//

import Foundation
@testable import VoiceFlow

/// Thread-safe mock settings service for testing
public final actor MockSettingsService: Sendable {
    
    // MARK: - Properties
    
    /// In-memory settings storage
    private var settings: [String: Any] = [:]
    
    /// Default values
    private var defaults: [String: Any] = [:]
    
    /// Change observers
    private var observers: [UUID: (String, Any) -> Void] = [:]
    
    /// Settings access count for testing
    private var accessCount: [String: Int] = [:]
    
    /// Error to throw on next operation
    private var nextError: Error?
    
    /// Persistence simulation
    private var isPersistent: Bool = true
    
    // MARK: - Types
    
    public enum MockError: LocalizedError, Sendable {
        case keyNotFound(String)
        case typeMismatch(String, expected: String, actual: String)
        case persistenceFailed
        case invalidValue(String)
        
        public var errorDescription: String? {
            switch self {
            case .keyNotFound(let key):
                return "Setting key not found: \(key)"
            case .typeMismatch(let key, let expected, let actual):
                return "Type mismatch for \(key): expected \(expected), got \(actual)"
            case .persistenceFailed:
                return "Failed to persist settings"
            case .invalidValue(let key):
                return "Invalid value for setting: \(key)"
            }
        }
    }
    
    public struct SettingChange: Sendable {
        public let key: String
        public let oldValue: Any?
        public let newValue: Any
        public let timestamp: Date
    }
    
    // MARK: - Configuration
    
    public func setDefaults(_ defaults: [String: Any]) {
        self.defaults = defaults
        
        // Apply defaults to current settings if not already set
        for (key, value) in defaults {
            if settings[key] == nil {
                settings[key] = value
            }
        }
    }
    
    public func setNextError(_ error: Error?) {
        self.nextError = error
    }
    
    public func setPersistent(_ persistent: Bool) {
        self.isPersistent = persistent
    }
    
    // MARK: - Settings Access
    
    public func get<T>(_ key: String, type: T.Type) async throws -> T {
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        // Track access
        accessCount[key, default: 0] += 1
        
        // Check settings first, then defaults
        let value = settings[key] ?? defaults[key]
        
        guard let value = value else {
            throw MockError.keyNotFound(key)
        }
        
        guard let typedValue = value as? T else {
            throw MockError.typeMismatch(
                key,
                expected: String(describing: T.self),
                actual: String(describing: type(of: value))
            )
        }
        
        return typedValue
    }
    
    public func set<T>(_ key: String, value: T) async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let oldValue = settings[key]
        settings[key] = value
        
        // Notify observers
        for observer in observers.values {
            observer(key, value)
        }
        
        // Track access
        accessCount[key, default: 0] += 1
        
        // Simulate persistence
        if isPersistent {
            try await persistSettings()
        }
    }
    
    public func remove(_ key: String) async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        settings.removeValue(forKey: key)
        
        // Notify observers
        if let defaultValue = defaults[key] {
            for observer in observers.values {
                observer(key, defaultValue)
            }
        }
    }
    
    public func reset() async {
        settings = defaults
        accessCount.removeAll()
        
        // Notify all observers
        for (key, value) in settings {
            for observer in observers.values {
                observer(key, value)
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    public func getBool(_ key: String) async throws -> Bool {
        return try await get(key, type: Bool.self)
    }
    
    public func getInt(_ key: String) async throws -> Int {
        return try await get(key, type: Int.self)
    }
    
    public func getDouble(_ key: String) async throws -> Double {
        return try await get(key, type: Double.self)
    }
    
    public func getString(_ key: String) async throws -> String {
        return try await get(key, type: String.self)
    }
    
    public func getData(_ key: String) async throws -> Data {
        return try await get(key, type: Data.self)
    }
    
    // MARK: - Observation
    
    @discardableResult
    public func observe(
        _ key: String,
        handler: @escaping (Any) -> Void
    ) -> UUID {
        let id = UUID()
        observers[id] = { observedKey, value in
            if observedKey == key {
                handler(value)
            }
        }
        return id
    }
    
    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    // MARK: - Testing Helpers
    
    public func getAccessCount(for key: String) -> Int {
        return accessCount[key] ?? 0
    }
    
    public func getTotalAccessCount() -> Int {
        return accessCount.values.reduce(0, +)
    }
    
    public func getAllSettings() -> [String: Any] {
        return settings
    }
    
    public func hasKey(_ key: String) -> Bool {
        return settings[key] != nil || defaults[key] != nil
    }
    
    private func persistSettings() async throws {
        // Simulate persistence delay
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // Randomly fail for testing resilience
        if Double.random(in: 0...1) < 0.01 { // 1% failure rate
            throw MockError.persistenceFailed
        }
    }
}

// MARK: - Preset Configurations

public extension MockSettingsService {
    
    /// Configures default VoiceFlow settings
    func configureVoiceFlowDefaults() async {
        await setDefaults([
            // General settings
            "launchAtLogin": false,
            "showInDock": true,
            "showFloatingWidget": true,
            
            // Transcription settings
            "transcriptionLanguage": "en-US",
            "continuousListening": false,
            "autoSave": true,
            "autoSaveInterval": 30.0,
            
            // Audio settings
            "inputDevice": "Default",
            "audioQuality": "high",
            "noiseReduction": true,
            "audioLevel": 0.7,
            
            // Export settings
            "defaultExportFormat": "markdown",
            "exportDirectory": "~/Documents/VoiceFlow",
            "includeTimestamps": true,
            "includeMetadata": true,
            
            // UI settings
            "theme": "system",
            "fontSize": 14,
            "fontFamily": "SF Pro",
            "windowOpacity": 0.95,
            
            // Privacy settings
            "analytics": false,
            "crashReporting": true,
            "shareTranscriptionData": false,
            
            // Performance settings
            "maxBufferSize": 1024 * 1024 * 10, // 10MB
            "processingThreads": 4,
            "enableHardwareAcceleration": true
        ])
    }
}

// MARK: - Test Factory

public struct MockSettingsServiceFactory {
    
    public static func createDefault() async -> MockSettingsService {
        let service = MockSettingsService()
        await service.configureVoiceFlowDefaults()
        return service
    }
    
    public static func createEmpty() -> MockSettingsService {
        return MockSettingsService()
    }
    
    public static func createWithCustomDefaults(_ defaults: [String: Any]) async -> MockSettingsService {
        let service = MockSettingsService()
        await service.setDefaults(defaults)
        return service
    }
    
    public static func createNonPersistent() async -> MockSettingsService {
        let service = await createDefault()
        await service.setPersistent(false)
        return service
    }
}