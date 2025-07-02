import Foundation

/// Provides comprehensive input validation and sanitization
public final class InputValidator {
    
    // MARK: - Constants
    
    private static let maxJSONSize = 10 * 1024 * 1024 // 10MB
    private static let maxStringLength = 1_000_000 // 1M characters
    private static let maxArrayElements = 10_000
    private static let maxDictionaryKeys = 5_000
    private static let maxNestingDepth = 10
    
    // MARK: - JSON Validation
    
    /// Validates JSON data with security checks
    public static func validateJSON(_ data: Data) throws -> Any {
        // Check size limit
        guard data.count <= maxJSONSize else {
            throw InputValidationError.dataTooLarge(data.count, maxJSONSize)
        }
        
        // Parse JSON
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers, .allowFragments])
        } catch {
            throw InputValidationError.invalidJSON(error.localizedDescription)
        }
        
        // Validate structure
        try validateJSONStructure(jsonObject, depth: 0)
        
        return jsonObject
    }
    
    /// Validates JSON structure recursively
    private static func validateJSONStructure(_ object: Any, depth: Int) throws {
        // Check nesting depth
        guard depth < maxNestingDepth else {
            throw InputValidationError.nestingTooDeep(depth, maxNestingDepth)
        }
        
        switch object {
        case let array as [Any]:
            // Check array size
            guard array.count <= maxArrayElements else {
                throw InputValidationError.arrayTooLarge(array.count, maxArrayElements)
            }
            
            // Validate each element
            for element in array {
                try validateJSONStructure(element, depth: depth + 1)
            }
            
        case let dictionary as [String: Any]:
            // Check dictionary size
            guard dictionary.count <= maxDictionaryKeys else {
                throw InputValidationError.dictionaryTooLarge(dictionary.count, maxDictionaryKeys)
            }
            
            // Validate keys and values
            for (key, value) in dictionary {
                try validateString(key, maxLength: 1000) // Reasonable key length
                try validateJSONStructure(value, depth: depth + 1)
            }
            
        case let string as String:
            try validateString(string)
            
        case is NSNumber, is Bool, is NSNull:
            // These are valid JSON primitives
            break
            
        default:
            throw InputValidationError.invalidJSONType("Unsupported type: \(type(of: object))")
        }
    }
    
    // MARK: - String Validation
    
    /// Validates and sanitizes a string
    public static func validateString(_ string: String, maxLength: Int = maxStringLength) throws {
        // Check length
        guard string.count <= maxLength else {
            throw InputValidationError.stringTooLong(string.count, maxLength)
        }
        
        // Check for null bytes
        if string.contains("\0") {
            throw InputValidationError.invalidCharacters("String contains null bytes")
        }
        
        // Check for control characters (except newline, tab, carriage return)
        let allowedControlChars = CharacterSet(charactersIn: "\n\r\t")
        let controlChars = CharacterSet.controlCharacters.subtracting(allowedControlChars)
        
        if string.rangeOfCharacter(from: controlChars) != nil {
            throw InputValidationError.invalidCharacters("String contains invalid control characters")
        }
    }
    
    /// Sanitizes a string for safe storage
    public static func sanitizeString(_ string: String, maxLength: Int = maxStringLength) -> String {
        var sanitized = string
        
        // Truncate if too long
        if sanitized.count > maxLength {
            let endIndex = sanitized.index(sanitized.startIndex, offsetBy: maxLength)
            sanitized = String(sanitized[..<endIndex])
        }
        
        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        
        // Remove control characters (except newline, tab, carriage return)
        let allowedControlChars = CharacterSet(charactersIn: "\n\r\t")
        let controlChars = CharacterSet.controlCharacters.subtracting(allowedControlChars)
        sanitized = sanitized.components(separatedBy: controlChars).joined()
        
        // Normalize whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized
    }
    
    // MARK: - Custom Vocabulary Validation
    
    /// Validates custom vocabulary entries
    public static func validateVocabularyEntry(phrase: String, soundsLike: String?, ipa: String?) throws {
        // Validate phrase
        try validateString(phrase, maxLength: 100)
        
        // Check for empty phrase
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else {
            throw InputValidationError.emptyInput("Vocabulary phrase cannot be empty")
        }
        
        // Validate sounds-like if provided
        if let soundsLike = soundsLike {
            try validateString(soundsLike, maxLength: 100)
        }
        
        // Validate IPA if provided
        if let ipa = ipa {
            try validateString(ipa, maxLength: 200)
            
            // Basic IPA character validation
            let ipaCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzæðŋɐɑɒɓɔɕɖɗɘəɚɛɜɝɞɟɠɡɢɣɤɥɦɧɨɪɫɬɭɮɯɰɱɲɳɴɵɶɷɸɹɺɻɼɽɾɿʀʁʂʃʄʅʆʇʈʉʊʋʌʍʎʏʐʑʒʓʔʕʖʗʘʙʚʛʜʝʞʟʠʡʢʣʤʥʦʧʨʩʪʫʬʭʮʯ")
            let modifiers = CharacterSet(charactersIn: "ˈˌːˑ˘ˤ˞ʰʷʲʱʴʵˠˁ˜̃̊̈̌̂́̀̄̆̋̏̌̽̚ᵐⁿᵑᶮᶯᵇᵈᶢᵍᶡᵏᵖᵗᶜᵛᶻᵝᶞᶿᵡᶲᵠᶴᵸ")
            let allowedChars = ipaCharacters.union(modifiers).union(.whitespaces).union(.punctuationCharacters)
            
            let ipaSet = CharacterSet(charactersIn: ipa)
            if !ipaSet.isSubset(of: allowedChars) {
                throw InputValidationError.invalidIPACharacters("IPA contains invalid characters")
            }
        }
    }
    
    // MARK: - Import Data Validation
    
    /// Validates imported session data
    public static func validateImportedSessions(_ data: Data) throws -> [StoredTranscriptionSession] {
        // First validate as JSON
        let jsonObject = try validateJSON(data)
        
        // Ensure it's an array
        guard let sessionsArray = jsonObject as? [[String: Any]] else {
            throw InputValidationError.invalidDataFormat("Expected array of sessions")
        }
        
        // Validate and decode each session
        var validatedSessions: [StoredTranscriptionSession] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for (index, sessionDict) in sessionsArray.enumerated() {
            do {
                // Convert back to data for decoding
                let sessionData = try JSONSerialization.data(withJSONObject: sessionDict)
                let session = try decoder.decode(StoredTranscriptionSession.self, from: sessionData)
                
                // Additional validation
                try validateTranscriptionSession(session)
                
                validatedSessions.append(session)
            } catch {
                throw InputValidationError.invalidSessionData(index, error.localizedDescription)
            }
        }
        
        return validatedSessions
    }
    
    /// Validates a transcription session
    private static func validateTranscriptionSession(_ session: StoredTranscriptionSession) throws {
        // Validate transcription text
        try validateString(session.transcription)
        
        // Validate metadata
        try validateString(session.language, maxLength: 10)
        try validateString(session.contextType, maxLength: 50)
        try validateString(session.privacy, maxLength: 20)
        
        // Validate numeric values
        guard session.duration >= 0 else {
            throw InputValidationError.invalidNumericValue("Duration cannot be negative")
        }
        
        guard session.wordCount >= 0 else {
            throw InputValidationError.invalidNumericValue("Word count cannot be negative")
        }
        
        guard session.averageConfidence >= 0 && session.averageConfidence <= 1 else {
            throw InputValidationError.invalidNumericValue("Average confidence must be between 0 and 1")
        }
        
        // Validate dates
        guard session.endTime >= session.startTime else {
            throw InputValidationError.invalidDateRange("End time must be after start time")
        }
        
        // Check for reasonable date range (not in the future, not too far in the past)
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        
        guard session.startTime <= now else {
            throw InputValidationError.invalidDateRange("Start time cannot be in the future")
        }
        
        guard session.startTime >= oneYearAgo else {
            throw InputValidationError.invalidDateRange("Start time is too far in the past")
        }
    }
    
    // MARK: - URL Validation
    
    /// Validates a URL string
    public static func validateURLString(_ urlString: String) throws -> URL {
        // Basic string validation
        try validateString(urlString, maxLength: 2048) // Reasonable URL length
        
        // Check for dangerous URL schemes
        let dangerousSchemes = ["javascript", "data", "vbscript", "file"]
        let lowercaseURL = urlString.lowercased()
        
        for scheme in dangerousSchemes {
            if lowercaseURL.hasPrefix("\(scheme):") {
                throw InputValidationError.dangerousURLScheme(scheme)
            }
        }
        
        // Try to create URL
        guard let url = URL(string: urlString) else {
            throw InputValidationError.invalidURL("Invalid URL format")
        }
        
        // Ensure it has a scheme
        guard url.scheme != nil else {
            throw InputValidationError.invalidURL("URL must have a scheme")
        }
        
        return url
    }
}

// MARK: - Input Validation Errors

public enum InputValidationError: LocalizedError {
    case dataTooLarge(Int, Int)
    case stringTooLong(Int, Int)
    case arrayTooLarge(Int, Int)
    case dictionaryTooLarge(Int, Int)
    case nestingTooDeep(Int, Int)
    case invalidJSON(String)
    case invalidJSONType(String)
    case invalidCharacters(String)
    case emptyInput(String)
    case invalidIPACharacters(String)
    case invalidDataFormat(String)
    case invalidSessionData(Int, String)
    case invalidNumericValue(String)
    case invalidDateRange(String)
    case dangerousURLScheme(String)
    case invalidURL(String)
    
    public var errorDescription: String? {
        switch self {
        case .dataTooLarge(let actual, let max):
            return "Data too large: \(actual) bytes (maximum: \(max))"
        case .stringTooLong(let actual, let max):
            return "String too long: \(actual) characters (maximum: \(max))"
        case .arrayTooLarge(let actual, let max):
            return "Array too large: \(actual) elements (maximum: \(max))"
        case .dictionaryTooLarge(let actual, let max):
            return "Dictionary too large: \(actual) keys (maximum: \(max))"
        case .nestingTooDeep(let actual, let max):
            return "Nesting too deep: \(actual) levels (maximum: \(max))"
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .invalidJSONType(let message):
            return "Invalid JSON type: \(message)"
        case .invalidCharacters(let message):
            return "Invalid characters: \(message)"
        case .emptyInput(let message):
            return "Empty input: \(message)"
        case .invalidIPACharacters(let message):
            return "Invalid IPA characters: \(message)"
        case .invalidDataFormat(let message):
            return "Invalid data format: \(message)"
        case .invalidSessionData(let index, let message):
            return "Invalid session at index \(index): \(message)"
        case .invalidNumericValue(let message):
            return "Invalid numeric value: \(message)"
        case .invalidDateRange(let message):
            return "Invalid date range: \(message)"
        case .dangerousURLScheme(let scheme):
            return "Dangerous URL scheme: \(scheme)"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        }
    }
}

// MARK: - Validation Result

public struct ValidationResult<T> {
    public let value: T
    public let warnings: [String]
    
    public init(value: T, warnings: [String] = []) {
        self.value = value
        self.warnings = warnings
    }
}

// Re-export StoredTranscriptionSession for validation
public struct StoredTranscriptionSession: Codable {
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
}