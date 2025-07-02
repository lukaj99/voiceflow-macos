import Foundation
import Combine

/// Protocol defining the interface for managing app settings
@MainActor
public protocol SettingsServiceProtocol: AnyObject, ObservableObject, Sendable {
    
    // MARK: - General Settings
    
    var launchAtLogin: Bool { get set }
    var showFloatingWidget: Bool { get set }
    var floatingWidgetAlwaysOnTop: Bool { get set }
    var menuBarIcon: MenuBarIconStyle { get set }
    
    // MARK: - Transcription Settings
    
    var selectedLanguage: String { get set }
    var enablePunctuation: Bool { get set }
    var enableCapitalization: Bool { get set }
    var confidenceThreshold: Double { get set }
    var enableContextAwareCorrections: Bool { get set }
    var enableRealTimeTranscription: Bool { get set }
    var autoSaveSessions: Bool { get set }
    
    // MARK: - Privacy Settings
    
    var privacyMode: PrivacyMode { get set }
    var dataRetentionDays: Int { get set }
    var enableAnalytics: Bool { get set }
    var enableCrashReporting: Bool { get set }
    
    // MARK: - Advanced Settings
    
    var customVocabulary: [String] { get set }
    var preferOnDeviceRecognition: Bool { get set }
    var enableDeveloperMode: Bool { get set }
    var logLevel: LogLevel { get set }
    var maxBufferSize: Int { get set }
    
    // MARK: - Methods
    
    func resetToDefaults()
    func exportSettings() throws -> Data
    func importSettings(from data: Data) throws
    func addCustomVocabularyWord(_ word: String)
    func removeCustomVocabularyWord(_ word: String)
    func getAvailableLanguages() -> [VoiceLanguage]
}

// MARK: - Default Implementation Extension

extension SettingsServiceProtocol {
    /// Default implementation for adding vocabulary words
    public func addCustomVocabularyWord(_ word: String) {
        guard !word.isEmpty && !customVocabulary.contains(word) else { return }
        var vocabulary = customVocabulary
        vocabulary.append(word)
        customVocabulary = vocabulary
    }
    
    /// Default implementation for removing vocabulary words
    public func removeCustomVocabularyWord(_ word: String) {
        customVocabulary = customVocabulary.filter { $0 != word }
    }
}