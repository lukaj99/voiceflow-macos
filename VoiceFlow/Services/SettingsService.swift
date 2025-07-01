import Foundation
import Combine

/// Centralized service for managing all app settings
@MainActor
public final class SettingsService: ObservableObject {
    
    // MARK: - General Settings
    
    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
            if launchAtLogin {
                launchAtLoginService.enable()
            } else {
                launchAtLoginService.disable()
            }
        }
    }
    
    @Published public var showFloatingWidget: Bool {
        didSet { UserDefaults.standard.set(showFloatingWidget, forKey: "ShowFloatingWidget") }
    }
    
    @Published public var floatingWidgetAlwaysOnTop: Bool {
        didSet { UserDefaults.standard.set(floatingWidgetAlwaysOnTop, forKey: "FloatingWidgetAlwaysOnTop") }
    }
    
    @Published public var menuBarIcon: MenuBarIconStyle {
        didSet { UserDefaults.standard.set(menuBarIcon.rawValue, forKey: "MenuBarIcon") }
    }
    
    // MARK: - Transcription Settings
    
    @Published public var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage") }
    }
    
    @Published public var enablePunctuation: Bool {
        didSet { UserDefaults.standard.set(enablePunctuation, forKey: "EnablePunctuation") }
    }
    
    @Published public var enableCapitalization: Bool {
        didSet { UserDefaults.standard.set(enableCapitalization, forKey: "EnableCapitalization") }
    }
    
    @Published public var confidenceThreshold: Double {
        didSet { UserDefaults.standard.set(confidenceThreshold, forKey: "ConfidenceThreshold") }
    }
    
    @Published public var enableContextAwareCorrections: Bool {
        didSet { UserDefaults.standard.set(enableContextAwareCorrections, forKey: "EnableContextAwareCorrections") }
    }
    
    @Published public var enableRealTimeTranscription: Bool {
        didSet { UserDefaults.standard.set(enableRealTimeTranscription, forKey: "EnableRealTimeTranscription") }
    }
    
    @Published public var autoSaveSessions: Bool {
        didSet { UserDefaults.standard.set(autoSaveSessions, forKey: "AutoSaveSessions") }
    }
    
    // MARK: - Privacy Settings
    
    @Published public var privacyMode: PrivacyMode {
        didSet { UserDefaults.standard.set(privacyMode.rawValue, forKey: "PrivacyMode") }
    }
    
    @Published public var dataRetentionDays: Int {
        didSet { UserDefaults.standard.set(dataRetentionDays, forKey: "DataRetentionDays") }
    }
    
    @Published public var enableAnalytics: Bool {
        didSet { UserDefaults.standard.set(enableAnalytics, forKey: "EnableAnalytics") }
    }
    
    @Published public var enableCrashReporting: Bool {
        didSet { UserDefaults.standard.set(enableCrashReporting, forKey: "EnableCrashReporting") }
    }
    
    // MARK: - Advanced Settings
    
    @Published public var customVocabulary: [String] {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: "CustomVocabulary") }
    }
    
    @Published public var preferOnDeviceRecognition: Bool {
        didSet { UserDefaults.standard.set(preferOnDeviceRecognition, forKey: "PreferOnDeviceRecognition") }
    }
    
    @Published public var enableDeveloperMode: Bool {
        didSet { UserDefaults.standard.set(enableDeveloperMode, forKey: "EnableDeveloperMode") }
    }
    
    @Published public var logLevel: LogLevel {
        didSet { UserDefaults.standard.set(logLevel.rawValue, forKey: "LogLevel") }
    }
    
    @Published public var maxBufferSize: Int {
        didSet { UserDefaults.standard.set(maxBufferSize, forKey: "MaxBufferSize") }
    }
    
    // MARK: - Services
    
    private let launchAtLoginService = LaunchAtLoginService()
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    public init() {
        // Load general settings
        self.launchAtLogin = defaults.bool(forKey: "LaunchAtLogin")
        self.showFloatingWidget = defaults.object(forKey: "ShowFloatingWidget") as? Bool ?? true
        self.floatingWidgetAlwaysOnTop = defaults.object(forKey: "FloatingWidgetAlwaysOnTop") as? Bool ?? true
        self.menuBarIcon = MenuBarIconStyle(rawValue: defaults.string(forKey: "MenuBarIcon") ?? "") ?? .colored
        
        // Load transcription settings
        self.selectedLanguage = defaults.string(forKey: "SelectedLanguage") ?? "en-US"
        self.enablePunctuation = defaults.object(forKey: "EnablePunctuation") as? Bool ?? true
        self.enableCapitalization = defaults.object(forKey: "EnableCapitalization") as? Bool ?? true
        self.confidenceThreshold = defaults.object(forKey: "ConfidenceThreshold") as? Double ?? 0.7
        self.enableContextAwareCorrections = defaults.object(forKey: "EnableContextAwareCorrections") as? Bool ?? true
        self.enableRealTimeTranscription = defaults.object(forKey: "EnableRealTimeTranscription") as? Bool ?? true
        self.autoSaveSessions = defaults.object(forKey: "AutoSaveSessions") as? Bool ?? true
        
        // Load privacy settings
        self.privacyMode = PrivacyMode(rawValue: defaults.string(forKey: "PrivacyMode") ?? "") ?? .balanced
        self.dataRetentionDays = defaults.object(forKey: "DataRetentionDays") as? Int ?? 30
        self.enableAnalytics = defaults.object(forKey: "EnableAnalytics") as? Bool ?? false
        self.enableCrashReporting = defaults.object(forKey: "EnableCrashReporting") as? Bool ?? true
        
        // Load advanced settings
        self.customVocabulary = defaults.stringArray(forKey: "CustomVocabulary") ?? []
        self.preferOnDeviceRecognition = defaults.object(forKey: "PreferOnDeviceRecognition") as? Bool ?? true
        self.enableDeveloperMode = defaults.object(forKey: "EnableDeveloperMode") as? Bool ?? false
        self.logLevel = LogLevel(rawValue: defaults.string(forKey: "LogLevel") ?? "") ?? .info
        self.maxBufferSize = defaults.object(forKey: "MaxBufferSize") as? Int ?? 1024
    }
    
    // MARK: - Public Methods
    
    public func resetToDefaults() {
        // General settings
        launchAtLogin = false
        showFloatingWidget = true
        floatingWidgetAlwaysOnTop = true
        menuBarIcon = .colored
        
        // Transcription settings
        selectedLanguage = "en-US"
        enablePunctuation = true
        enableCapitalization = true
        confidenceThreshold = 0.7
        enableContextAwareCorrections = true
        enableRealTimeTranscription = true
        autoSaveSessions = true
        
        // Privacy settings
        privacyMode = .balanced
        dataRetentionDays = 30
        enableAnalytics = false
        enableCrashReporting = true
        
        // Advanced settings
        customVocabulary = []
        preferOnDeviceRecognition = true
        enableDeveloperMode = false
        logLevel = .info
        maxBufferSize = 1024
    }
    
    public func exportSettings() throws -> Data {
        let settings = ExportableSettings(
            launchAtLogin: launchAtLogin,
            showFloatingWidget: showFloatingWidget,
            floatingWidgetAlwaysOnTop: floatingWidgetAlwaysOnTop,
            menuBarIcon: menuBarIcon,
            selectedLanguage: selectedLanguage,
            enablePunctuation: enablePunctuation,
            enableCapitalization: enableCapitalization,
            confidenceThreshold: confidenceThreshold,
            enableContextAwareCorrections: enableContextAwareCorrections,
            enableRealTimeTranscription: enableRealTimeTranscription,
            autoSaveSessions: autoSaveSessions,
            privacyMode: privacyMode,
            dataRetentionDays: dataRetentionDays,
            enableAnalytics: enableAnalytics,
            enableCrashReporting: enableCrashReporting,
            customVocabulary: customVocabulary,
            preferOnDeviceRecognition: preferOnDeviceRecognition,
            logLevel: logLevel,
            maxBufferSize: maxBufferSize
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let decoder = JSONDecoder()
        let settings = try decoder.decode(ExportableSettings.self, from: data)
        
        // Apply imported settings
        launchAtLogin = settings.launchAtLogin
        showFloatingWidget = settings.showFloatingWidget
        floatingWidgetAlwaysOnTop = settings.floatingWidgetAlwaysOnTop
        menuBarIcon = settings.menuBarIcon
        selectedLanguage = settings.selectedLanguage
        enablePunctuation = settings.enablePunctuation
        enableCapitalization = settings.enableCapitalization
        confidenceThreshold = settings.confidenceThreshold
        enableContextAwareCorrections = settings.enableContextAwareCorrections
        enableRealTimeTranscription = settings.enableRealTimeTranscription
        autoSaveSessions = settings.autoSaveSessions
        privacyMode = settings.privacyMode
        dataRetentionDays = settings.dataRetentionDays
        enableAnalytics = settings.enableAnalytics
        enableCrashReporting = settings.enableCrashReporting
        customVocabulary = settings.customVocabulary
        preferOnDeviceRecognition = settings.preferOnDeviceRecognition
        logLevel = settings.logLevel
        maxBufferSize = settings.maxBufferSize
    }
    
    public func addCustomVocabularyWord(_ word: String) {
        guard !word.isEmpty && !customVocabulary.contains(word) else { return }
        customVocabulary.append(word)
    }
    
    public func removeCustomVocabularyWord(_ word: String) {
        customVocabulary.removeAll { $0 == word }
    }
    
    public func getAvailableLanguages() -> [VoiceLanguage] {
        return [
            VoiceVoiceLanguage(code: "en-US", name: "English (US)", flag: "🇺🇸"),
            VoiceLanguage(code: "en-GB", name: "English (UK)", flag: "🇬🇧"),
            VoiceLanguage(code: "en-AU", name: "English (Australia)", flag: "🇦🇺"),
            VoiceLanguage(code: "en-CA", name: "English (Canada)", flag: "🇨🇦"),
            VoiceLanguage(code: "es-ES", name: "Spanish (Spain)", flag: "🇪🇸"),
            VoiceLanguage(code: "es-MX", name: "Spanish (Mexico)", flag: "🇲🇽"),
            VoiceLanguage(code: "fr-FR", name: "French (France)", flag: "🇫🇷"),
            VoiceLanguage(code: "fr-CA", name: "French (Canada)", flag: "🇨🇦"),
            VoiceLanguage(code: "de-DE", name: "German", flag: "🇩🇪"),
            VoiceLanguage(code: "it-IT", name: "Italian", flag: "🇮🇹"),
            VoiceLanguage(code: "pt-BR", name: "Portuguese (Brazil)", flag: "🇧🇷"),
            VoiceLanguage(code: "pt-PT", name: "Portuguese (Portugal)", flag: "🇵🇹"),
            VoiceLanguage(code: "ru-RU", name: "Russian", flag: "🇷🇺"),
            VoiceLanguage(code: "ja-JP", name: "Japanese", flag: "🇯🇵"),
            VoiceLanguage(code: "ko-KR", name: "Korean", flag: "🇰🇷"),
            VoiceLanguage(code: "zh-CN", name: "Chinese (Simplified)", flag: "🇨🇳"),
            VoiceLanguage(code: "zh-TW", name: "Chinese (Traditional)", flag: "🇹🇼"),
            VoiceLanguage(code: "ar-SA", name: "Arabic", flag: "🇸🇦"),
            VoiceLanguage(code: "hi-IN", name: "Hindi", flag: "🇮🇳"),
            VoiceLanguage(code: "th-TH", name: "Thai", flag: "🇹🇭"),
            VoiceLanguage(code: "vi-VN", name: "Vietnamese", flag: "🇻🇳"),
            VoiceLanguage(code: "nl-NL", name: "Dutch", flag: "🇳🇱"),
            VoiceLanguage(code: "sv-SE", name: "Swedish", flag: "🇸🇪"),
            VoiceLanguage(code: "da-DK", name: "Danish", flag: "🇩🇰"),
            VoiceLanguage(code: "no-NO", name: "Norwegian", flag: "🇳🇴"),
            VoiceLanguage(code: "fi-FI", name: "Finnish", flag: "🇫🇮"),
            VoiceLanguage(code: "pl-PL", name: "Polish", flag: "🇵🇱"),
            VoiceLanguage(code: "cs-CZ", name: "Czech", flag: "🇨🇿"),
            VoiceLanguage(code: "hu-HU", name: "Hungarian", flag: "🇭🇺"),
            VoiceLanguage(code: "ro-RO", name: "Romanian", flag: "🇷🇴"),
            VoiceLanguage(code: "sk-SK", name: "Slovak", flag: "🇸🇰"),
            VoiceLanguage(code: "hr-HR", name: "Croatian", flag: "🇭🇷"),
            VoiceLanguage(code: "uk-UA", name: "Ukrainian", flag: "🇺🇦"),
            VoiceLanguage(code: "bg-BG", name: "Bulgarian", flag: "🇧🇬"),
            VoiceLanguage(code: "lt-LT", name: "Lithuanian", flag: "🇱🇹"),
            VoiceLanguage(code: "lv-LV", name: "Latvian", flag: "🇱🇻"),
            VoiceLanguage(code: "et-EE", name: "Estonian", flag: "🇪🇪"),
            VoiceLanguage(code: "sl-SI", name: "Slovenian", flag: "🇸🇮"),
            VoiceLanguage(code: "he-IL", name: "Hebrew", flag: "🇮🇱"),
            VoiceLanguage(code: "tr-TR", name: "Turkish", flag: "🇹🇷")
        ]
    }
}

// MARK: - Supporting Types

public enum MenuBarIconStyle: String, CaseIterable, Codable {
    case colored = "colored"
    case monochrome = "monochrome"
    case hidden = "hidden"
    
    public var displayName: String {
        switch self {
        case .colored: return "Colored"
        case .monochrome: return "Monochrome"
        case .hidden: return "Hidden"
        }
    }
}

public enum LogLevel: String, CaseIterable, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    public var displayName: String {
        rawValue.capitalized
    }
}

public struct VoiceLanguage: Identifiable, Codable {
    public let id = UUID()
    public let code: String
    public let name: String
    public let flag: String
    
    public var displayName: String {
        "\(flag) \(name)"
    }
}

private struct ExportableSettings: Codable {
    let launchAtLogin: Bool
    let showFloatingWidget: Bool
    let floatingWidgetAlwaysOnTop: Bool
    let menuBarIcon: MenuBarIconStyle
    let selectedLanguage: String
    let enablePunctuation: Bool
    let enableCapitalization: Bool
    let confidenceThreshold: Double
    let enableContextAwareCorrections: Bool
    let enableRealTimeTranscription: Bool
    let autoSaveSessions: Bool
    let privacyMode: PrivacyMode
    let dataRetentionDays: Int
    let enableAnalytics: Bool
    let enableCrashReporting: Bool
    let customVocabulary: [String]
    let preferOnDeviceRecognition: Bool
    let logLevel: LogLevel
    let maxBufferSize: Int
}