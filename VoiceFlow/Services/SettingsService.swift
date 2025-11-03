import Foundation
import Combine

/// Production SettingsService actor for persistent user preferences
/// Replaces mock implementation with real UserDefaults-backed storage
public actor SettingsService {

    // MARK: - Types

    public enum SettingsError: LocalizedError, Sendable {
        case invalidValue(String)
        case persistenceFailure(String)
        case keyNotFound(String)
        case typeMismatch(String, expected: String, actual: String)

        public var errorDescription: String? {
            switch self {
            case .invalidValue(let key):
                return "Invalid value for setting: \(key)"
            case .persistenceFailure(let reason):
                return "Failed to persist settings: \(reason)"
            case .keyNotFound(let key):
                return "Setting not found: \(key)"
            case .typeMismatch(let key, let expected, let actual):
                return "Type mismatch for \(key): expected \(expected), got \(actual)"
            }
        }
    }

    public enum SettingsKey: String, CaseIterable, Sendable {
        // General settings
        case launchAtLogin = "launch_at_login"
        case showInDock = "show_in_dock"
        case showFloatingWidget = "show_floating_widget"
        case enableMenuBarIcon = "enable_menu_bar_icon"

        // Transcription settings
        case transcriptionLanguage = "transcription_language"
        case continuousListening = "continuous_listening"
        case autoSave = "auto_save"
        case autoSaveInterval = "auto_save_interval"
        case enableCustomVocabulary = "enable_custom_vocabulary"

        // Audio settings
        case inputDevice = "input_device"
        case audioQuality = "audio_quality"
        case noiseReduction = "noise_reduction"
        case audioLevel = "audio_level"
        case audioBufferSize = "audio_buffer_size"

        // Export settings
        case defaultExportFormat = "default_export_format"
        case exportDirectory = "export_directory"
        case includeTimestamps = "include_timestamps"
        case includeMetadata = "include_metadata"
        case exportFilenamePattern = "export_filename_pattern"

        // UI settings
        case theme = "theme"
        case fontSize = "font_size"
        case fontFamily = "font_family"
        case windowOpacity = "window_opacity"
        case compactMode = "compact_mode"

        // Privacy settings
        case analytics = "analytics"
        case crashReporting = "crash_reporting"
        case shareTranscriptionData = "share_transcription_data"
        case privacyMode = "privacy_mode"

        // Performance settings
        case maxBufferSize = "max_buffer_size"
        case processingThreads = "processing_threads"
        case enableHardwareAcceleration = "enable_hardware_acceleration"
        case networkTimeout = "network_timeout"

        // Hotkey settings
        case recordingHotkey = "recording_hotkey"
        case pauseHotkey = "pause_hotkey"
        case stopHotkey = "stop_hotkey"
        case enableGlobalHotkeys = "enable_global_hotkeys"

        // Advanced settings
        case debugMode = "debug_mode"
        case logLevel = "log_level"
        case enableExperimentalFeatures = "enable_experimental_features"

        var defaultValue: Any {
            switch self {
            // General settings
            case .launchAtLogin: return false
            case .showInDock: return true
            case .showFloatingWidget: return false
            case .enableMenuBarIcon: return true

            // Transcription settings
            case .transcriptionLanguage: return "en-US"
            case .continuousListening: return false
            case .autoSave: return true
            case .autoSaveInterval: return 30.0
            case .enableCustomVocabulary: return false

            // Audio settings
            case .inputDevice: return "Default"
            case .audioQuality: return "high"
            case .noiseReduction: return true
            case .audioLevel: return 0.7
            case .audioBufferSize: return 1024

            // Export settings
            case .defaultExportFormat: return "markdown"
            case .exportDirectory: return "~/Documents/VoiceFlow"
            case .includeTimestamps: return true
            case .includeMetadata: return true
            case .exportFilenamePattern: return "VoiceFlow_%date%_%time%"

            // UI settings
            case .theme: return "system"
            case .fontSize: return 14
            case .fontFamily: return "SF Pro"
            case .windowOpacity: return 0.95
            case .compactMode: return false

            // Privacy settings
            case .analytics: return false
            case .crashReporting: return true
            case .shareTranscriptionData: return false
            case .privacyMode: return "balanced"

            // Performance settings
            case .maxBufferSize: return 1024 * 1024 * 10 // 10MB
            case .processingThreads: return 4
            case .enableHardwareAcceleration: return true
            case .networkTimeout: return 30.0

            // Hotkey settings
            case .recordingHotkey: return "cmd+shift+r"
            case .pauseHotkey: return "cmd+shift+p"
            case .stopHotkey: return "cmd+shift+s"
            case .enableGlobalHotkeys: return true

            // Advanced settings
            case .debugMode: return false
            case .logLevel: return "info"
            case .enableExperimentalFeatures: return false
            }
        }
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let suiteName = "com.voiceflow.settings"

    // Observers for settings changes
    private var observers: [UUID: @Sendable (SettingsKey, Any) -> Void] = [:]

    // Cache for frequently accessed settings
    private var settingsCache: [SettingsKey: Any] = [:]

    // MARK: - Initialization

    public init() {
        // Use app group suite for shared settings if available
        if let appGroupID = Bundle.main.object(forInfoDictionaryKey: "VoiceFlowAppGroup") as? String {
            self.userDefaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        } else {
            self.userDefaults = UserDefaults.standard
        }

        print("⚙️ SettingsService initialized with UserDefaults storage")

        // Initialize default values
        Task {
            await initializeDefaults()
        }
    }

    // MARK: - Core Settings Interface

    /// Get a typed setting value
    public func get<T>(_ key: SettingsKey, type: T.Type) async throws -> T {
        // Check cache first
        if let cached = settingsCache[key] as? T {
            return cached
        }

        // Get from UserDefaults
        let value = userDefaults.object(forKey: key.rawValue) ?? key.defaultValue

        guard let typedValue = value as? T else {
            throw SettingsError.typeMismatch(
                key.rawValue,
                expected: String(describing: T.self),
                actual: String(describing: Swift.type(of: value))
            )
        }

        // Cache the value
        settingsCache[key] = typedValue

        return typedValue
    }

    /// Set a setting value
    public func set<T>(_ key: SettingsKey, value: T) async throws {
        // Validate the value
        try await validateValue(value, for: key)

        // Store in UserDefaults
        userDefaults.set(value, forKey: key.rawValue)

        // Update cache
        settingsCache[key] = value

        // Notify observers
        for observer in observers.values {
            observer(key, value)
        }

        print("⚙️ Setting updated: \(key.rawValue) = \(value)")
    }

    /// Remove a setting (reset to default)
    public func reset(_ key: SettingsKey) async {
        userDefaults.removeObject(forKey: key.rawValue)
        settingsCache.removeValue(forKey: key)

        // Notify observers with default value
        for observer in observers.values {
            observer(key, key.defaultValue)
        }

        print("⚙️ Setting reset to default: \(key.rawValue)")
    }

    /// Reset all settings to defaults
    public func resetAll() async {
        for key in SettingsKey.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }

        settingsCache.removeAll()
        await initializeDefaults()

        print("⚙️ All settings reset to defaults")
    }

    // MARK: - Observation

    /// Add an observer for settings changes
    @discardableResult
    public func observe(
        _ key: SettingsKey,
        handler: @escaping @Sendable (Any) -> Void
    ) -> UUID {
        let id = UUID()
        observers[id] = { observedKey, value in
            if observedKey == key {
                handler(value)
            }
        }
        return id
    }

    /// Remove an observer
    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    // MARK: - Private Methods

    /// Initialize default values in UserDefaults
    private func initializeDefaults() async {
        var defaults: [String: Any] = [:]

        for key in SettingsKey.allCases where userDefaults.object(forKey: key.rawValue) == nil {
            defaults[key.rawValue] = key.defaultValue
        }

        if !defaults.isEmpty {
            userDefaults.register(defaults: defaults)
            print("⚙️ Initialized \(defaults.count) default settings")
        }
    }

    /// Validate a value for a specific setting key
    private func validateValue<T>(_ value: T, for key: SettingsKey) async throws {
        // Extract validation to separate methods by type
        try validateDoubleRange(value, for: key)
        try validateIntRange(value, for: key)
    }

    private func validateDoubleRange<T>(_ value: T, for key: SettingsKey) throws {
        guard let doubleValue = value as? Double else { return }

        switch key {
        case .audioLevel:
            guard doubleValue >= 0.0 && doubleValue <= 1.0 else {
                throw SettingsError.invalidValue("Audio level must be between 0.0 and 1.0")
            }
        case .autoSaveInterval:
            guard doubleValue >= 5.0 else {
                throw SettingsError.invalidValue("Auto-save interval must be at least 5 seconds")
            }
        case .windowOpacity:
            guard doubleValue >= 0.1 && doubleValue <= 1.0 else {
                throw SettingsError.invalidValue("Window opacity must be between 0.1 and 1.0")
            }
        case .networkTimeout:
            guard doubleValue >= 5.0 && doubleValue <= 300.0 else {
                throw SettingsError.invalidValue("Network timeout must be between 5 and 300 seconds")
            }
        default:
            break
        }
    }

    private func validateIntRange<T>(_ value: T, for key: SettingsKey) throws {
        guard let intValue = value as? Int else { return }

        switch key {
        case .fontSize:
            guard intValue >= 8 && intValue <= 72 else {
                throw SettingsError.invalidValue("Font size must be between 8 and 72")
            }
        case .processingThreads:
            guard intValue >= 1 && intValue <= 16 else {
                throw SettingsError.invalidValue("Processing threads must be between 1 and 16")
            }
        default:
            break
        }
    }
}

// MARK: - Convenience Methods Extension

extension SettingsService {
    public func getBool(_ key: SettingsKey) async throws -> Bool {
        return try await get(key, type: Bool.self)
    }

    public func getInt(_ key: SettingsKey) async throws -> Int {
        return try await get(key, type: Int.self)
    }

    public func getDouble(_ key: SettingsKey) async throws -> Double {
        return try await get(key, type: Double.self)
    }

    public func getString(_ key: SettingsKey) async throws -> String {
        return try await get(key, type: String.self)
    }

    public func setBool(_ key: SettingsKey, value: Bool) async throws {
        try await set(key, value: value)
    }

    public func setInt(_ key: SettingsKey, value: Int) async throws {
        try await set(key, value: value)
    }

    public func setDouble(_ key: SettingsKey, value: Double) async throws {
        try await set(key, value: value)
    }

    public func setString(_ key: SettingsKey, value: String) async throws {
        try await set(key, value: value)
    }
}

// MARK: - Bulk Operations Extension

extension SettingsService {
    /// Get multiple settings at once
    public func getMultiple(_ keys: [SettingsKey]) async -> [SettingsKey: Any] {
        var results: [SettingsKey: Any] = [:]

        for key in keys {
            let value = userDefaults.object(forKey: key.rawValue) ?? key.defaultValue
            results[key] = value
            settingsCache[key] = value
        }

        return results
    }

    /// Set multiple settings at once
    public func setMultiple(_ settings: [SettingsKey: Any]) async throws {
        for (key, value) in settings {
            try await validateValue(value, for: key)
            userDefaults.set(value, forKey: key.rawValue)
            settingsCache[key] = value
        }

        // Notify observers
        for (key, value) in settings {
            for observer in observers.values {
                observer(key, value)
            }
        }

        print("⚙️ Multiple settings updated: \(settings.keys.map(\.rawValue))")
    }

    /// Export all settings to a dictionary
    public func exportSettings() async -> [String: Any] {
        var exported: [String: Any] = [:]

        for key in SettingsKey.allCases {
            let value = userDefaults.object(forKey: key.rawValue) ?? key.defaultValue
            exported[key.rawValue] = value
        }

        return exported
    }

    /// Import settings from a dictionary
    public func importSettings(_ settings: [String: Any]) async throws {
        var validSettings: [SettingsKey: Any] = [:]

        for (keyString, value) in settings {
            guard let key = SettingsKey(rawValue: keyString) else {
                print("⚠️ Unknown setting key ignored: \(keyString)")
                continue
            }

            try await validateValue(value, for: key)
            validSettings[key] = value
        }

        try await setMultiple(validSettings)
        print("⚙️ Settings imported successfully")
    }
}

// MARK: - Synchronous Bridge

/// Synchronous bridge for SwiftUI @AppStorage compatibility
@MainActor
public final class SettingsStore: ObservableObject {
    private let settingsService: SettingsService

    public init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    /// Get a setting synchronously (cached)
    public func get<T>(_ key: SettingsService.SettingsKey, type: T.Type) -> T {
        // This should only be used for cached values
        let value = UserDefaults.standard.object(forKey: key.rawValue) ?? key.defaultValue
        guard let typedValue = value as? T else {
            // Return default value if cast fails
            if let defaultValue = key.defaultValue as? T {
                return defaultValue
            }
            fatalError("Unable to cast setting value for key: \(key.rawValue)")
        }
        return typedValue
    }

    /// Set a setting asynchronously
    public func set<T>(_ key: SettingsService.SettingsKey, value: T) {
        Task {
            try? await settingsService.set(key, value: value)
        }
    }
}
