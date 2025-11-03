import Foundation
import Combine

/// Service responsible for managing language data and localization following Single Responsibility Principle
@MainActor
public final class LanguageService: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var availableLanguages: [VoiceLanguage] = []
    @Published public var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
            NotificationCenter.default.post(name: .languageDidChange, object: selectedLanguage)
        }
    }

    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    public init() {
        // Load selected language from defaults
        self.selectedLanguage = defaults.string(forKey: "SelectedLanguage") ?? "en-US"

        // Initialize available languages
        loadAvailableLanguages()
    }

    // MARK: - Public Methods

    public func getAvailableLanguages() -> [VoiceLanguage] {
        return availableLanguages
    }

    public func setSelectedLanguage(_ languageCode: String) {
        guard availableLanguages.contains(where: { $0.code == languageCode }) else {
            print("Warning: Language code '\(languageCode)' is not available")
            return
        }

        selectedLanguage = languageCode
    }

    public func getSelectedLanguage() -> VoiceLanguage? {
        return availableLanguages.first { $0.code == selectedLanguage }
    }

    public func isLanguageSupported(_ languageCode: String) -> Bool {
        return availableLanguages.contains { $0.code == languageCode }
    }

    public func getLanguagesByRegion() -> [String: [VoiceLanguage]] {
        return Dictionary(grouping: availableLanguages) { language in
            getRegionFromLanguageCode(language.code)
        }
    }

    public func searchLanguages(_ query: String) -> [VoiceLanguage] {
        guard !query.isEmpty else { return availableLanguages }

        let lowercasedQuery = query.lowercased()
        return availableLanguages.filter { language in
            language.name.lowercased().contains(lowercasedQuery) ||
            language.code.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - Private Methods

    private func loadAvailableLanguages() {
        availableLanguages = [
            // English variants
            VoiceLanguage(code: "en-US", name: "English (US)", flag: "🇺🇸", region: "North America"),
            VoiceLanguage(code: "en-GB", name: "English (UK)", flag: "🇬🇧", region: "Europe"),
            VoiceLanguage(code: "en-AU", name: "English (Australia)", flag: "🇦🇺", region: "Oceania"),
            VoiceLanguage(code: "en-CA", name: "English (Canada)", flag: "🇨🇦", region: "North America"),

            // Spanish variants
            VoiceLanguage(code: "es-ES", name: "Spanish (Spain)", flag: "🇪🇸", region: "Europe"),
            VoiceLanguage(code: "es-MX", name: "Spanish (Mexico)", flag: "🇲🇽", region: "North America"),
            VoiceLanguage(code: "es-AR", name: "Spanish (Argentina)", flag: "🇦🇷", region: "South America"),

            // French variants
            VoiceLanguage(code: "fr-FR", name: "French (France)", flag: "🇫🇷", region: "Europe"),
            VoiceLanguage(code: "fr-CA", name: "French (Canada)", flag: "🇨🇦", region: "North America"),

            // German
            VoiceLanguage(code: "de-DE", name: "German", flag: "🇩🇪", region: "Europe"),

            // Italian
            VoiceLanguage(code: "it-IT", name: "Italian", flag: "🇮🇹", region: "Europe"),

            // Portuguese variants
            VoiceLanguage(code: "pt-BR", name: "Portuguese (Brazil)", flag: "🇧🇷", region: "South America"),
            VoiceLanguage(code: "pt-PT", name: "Portuguese (Portugal)", flag: "🇵🇹", region: "Europe"),

            // Slavic languages
            VoiceLanguage(code: "ru-RU", name: "Russian", flag: "🇷🇺", region: "Europe"),
            VoiceLanguage(code: "pl-PL", name: "Polish", flag: "🇵🇱", region: "Europe"),
            VoiceLanguage(code: "cs-CZ", name: "Czech", flag: "🇨🇿", region: "Europe"),
            VoiceLanguage(code: "sk-SK", name: "Slovak", flag: "🇸🇰", region: "Europe"),
            VoiceLanguage(code: "hr-HR", name: "Croatian", flag: "🇭🇷", region: "Europe"),
            VoiceLanguage(code: "uk-UA", name: "Ukrainian", flag: "🇺🇦", region: "Europe"),

            // Asian languages
            VoiceLanguage(code: "ja-JP", name: "Japanese", flag: "🇯🇵", region: "Asia"),
            VoiceLanguage(code: "ko-KR", name: "Korean", flag: "🇰🇷", region: "Asia"),
            VoiceLanguage(code: "zh-CN", name: "Chinese (Simplified)", flag: "🇨🇳", region: "Asia"),
            VoiceLanguage(code: "zh-TW", name: "Chinese (Traditional)", flag: "🇹🇼", region: "Asia"),
            VoiceLanguage(code: "hi-IN", name: "Hindi", flag: "🇮🇳", region: "Asia"),
            VoiceLanguage(code: "th-TH", name: "Thai", flag: "🇹🇭", region: "Asia"),
            VoiceLanguage(code: "vi-VN", name: "Vietnamese", flag: "🇻🇳", region: "Asia"),

            // Middle Eastern languages
            VoiceLanguage(code: "ar-SA", name: "Arabic", flag: "🇸🇦", region: "Middle East"),
            VoiceLanguage(code: "he-IL", name: "Hebrew", flag: "🇮🇱", region: "Middle East"),
            VoiceLanguage(code: "tr-TR", name: "Turkish", flag: "🇹🇷", region: "Middle East"),

            // Nordic languages
            VoiceLanguage(code: "sv-SE", name: "Swedish", flag: "🇸🇪", region: "Europe"),
            VoiceLanguage(code: "da-DK", name: "Danish", flag: "🇩🇰", region: "Europe"),
            VoiceLanguage(code: "no-NO", name: "Norwegian", flag: "🇳🇴", region: "Europe"),
            VoiceLanguage(code: "fi-FI", name: "Finnish", flag: "🇫🇮", region: "Europe"),

            // Other European languages
            VoiceLanguage(code: "nl-NL", name: "Dutch", flag: "🇳🇱", region: "Europe"),
            VoiceLanguage(code: "hu-HU", name: "Hungarian", flag: "🇭🇺", region: "Europe"),
            VoiceLanguage(code: "ro-RO", name: "Romanian", flag: "🇷🇴", region: "Europe"),
            VoiceLanguage(code: "bg-BG", name: "Bulgarian", flag: "🇧🇬", region: "Europe"),
            VoiceLanguage(code: "lt-LT", name: "Lithuanian", flag: "🇱🇹", region: "Europe"),
            VoiceLanguage(code: "lv-LV", name: "Latvian", flag: "🇱🇻", region: "Europe"),
            VoiceLanguage(code: "et-EE", name: "Estonian", flag: "🇪🇪", region: "Europe"),
            VoiceLanguage(code: "sl-SI", name: "Slovenian", flag: "🇸🇮", region: "Europe")
        ]
    }

    private func getRegionFromLanguageCode(_ code: String) -> String {
        guard let language = availableLanguages.first(where: { $0.code == code }) else {
            return "Unknown"
        }
        return language.region
    }
}
