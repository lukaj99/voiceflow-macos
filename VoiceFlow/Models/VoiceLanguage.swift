import Foundation

/// Model representing a voice language with enhanced metadata
public struct VoiceLanguage: Identifiable, Codable, Hashable {
    public let id = UUID()
    public let code: String
    public let name: String
    public let flag: String
    public let region: String

    private enum CodingKeys: String, CodingKey {
        case code, name, flag, region
    }

    public init(code: String, name: String, flag: String, region: String = "Unknown") {
        self.code = code
        self.name = name
        self.flag = flag
        self.region = region
    }

    public var displayName: String {
        "\(flag) \(name)"
    }

    public var shortDisplayName: String {
        "\(flag) \(name.components(separatedBy: " (").first ?? name)"
    }

    public var locale: Locale {
        Locale(identifier: code)
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    public static func == (lhs: VoiceLanguage, rhs: VoiceLanguage) -> Bool {
        lhs.code == rhs.code
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let languageDidChange = Notification.Name("languageDidChange")
}
