import Foundation

// MARK: - Security Usage Patterns
// This file demonstrates best practices for using VoiceFlow's security features

// MARK: - Encryption Patterns

extension SessionStorageService {
    /// Example: Encrypting sensitive metadata
    func encryptSensitiveMetadata(_ metadata: [String: String]) throws -> Data {
        // Validate input first
        for (key, value) in metadata {
            try InputValidator.validateString(key, maxLength: 100)
            try InputValidator.validateString(value, maxLength: 1000)
        }
        
        // Encrypt the validated data
        return try EncryptionService.shared.encryptCodable(metadata)
    }
}

// MARK: - File Validation Patterns

extension ExportManager {
    /// Example: Safe file export with validation
    func safeExportToUserSelectedPath(session: TranscriptionSession, 
                                    userPath: String,
                                    format: ExportFormat) async throws {
        // Convert string path to URL and validate
        let url = URL(fileURLWithPath: userPath)
        
        // This automatically validates the path for security
        try await exportToFile(session: session,
                             format: format,
                             fileURL: url,
                             configuration: nil,
                             progressDelegate: nil)
    }
}

// MARK: - Input Validation Patterns

extension VocabularyService {
    /// Example: Validating user-provided vocabulary
    func addCustomVocabularyEntry(phrase: String, 
                                soundsLike: String?,
                                ipa: String?) throws {
        // Sanitize inputs
        let sanitizedPhrase = InputValidator.sanitizeString(phrase)
        let sanitizedSoundsLike = soundsLike.map { InputValidator.sanitizeString($0) }
        let sanitizedIPA = ipa.map { InputValidator.sanitizeString($0) }
        
        // Validate
        try InputValidator.validateVocabularyEntry(
            phrase: sanitizedPhrase,
            soundsLike: sanitizedSoundsLike,
            ipa: sanitizedIPA
        )
        
        // Safe to use validated inputs
        // ... add to vocabulary
    }
}

// MARK: - Secure Import Patterns

extension SessionStorageService {
    /// Example: Importing sessions from untrusted source
    func importFromUntrustedSource(_ data: Data, source: String) async throws {
        // Log the import attempt (for audit trail)
        print("Import attempt from source: \(source)")
        
        // Validate data size first
        guard data.count < 50 * 1024 * 1024 else { // 50MB limit
            throw InputValidationError.dataTooLarge(data.count, 50 * 1024 * 1024)
        }
        
        // Use the built-in secure import
        try await importSessionsFromJSON(data)
        
        print("Import successful from source: \(source)")
    }
}

// MARK: - Migration Patterns

extension SessionStorageService {
    /// Example: Bulk migration of legacy data
    func migrateAllLegacyData() async throws {
        print("Starting legacy data migration...")
        
        // The loadSessions() method automatically handles migration
        await loadSessions()
        
        // Verify all sessions are now encrypted
        let sessionFiles = try FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        )
        
        let legacyCount = sessionFiles.filter { $0.pathExtension == "json" }.count
        let encryptedCount = sessionFiles.filter { $0.pathExtension == "enc" }.count
        
        print("Migration complete: \(encryptedCount) encrypted, \(legacyCount) legacy remaining")
    }
}

// MARK: - Error Handling Patterns

struct SecurityErrorHandler {
    /// Example: Handling security errors gracefully
    static func handleSecurityError(_ error: Error) -> String {
        switch error {
        case let encryptionError as EncryptionError:
            // Don't expose internal details
            return "Unable to process secure data. Please try again."
            
        case let validationError as FileValidationError:
            // Provide user-friendly message
            switch validationError {
            case .fileAlreadyExists:
                return "A file with this name already exists. Please choose a different name."
            case .directoryNotAllowed:
                return "Please select a location in your Documents or Downloads folder."
            default:
                return "Invalid file location selected."
            }
            
        case let inputError as InputValidationError:
            // Guide user to fix input
            switch inputError {
            case .stringTooLong(_, let max):
                return "Input is too long. Maximum \(max) characters allowed."
            case .invalidCharacters:
                return "Input contains invalid characters. Please use only letters, numbers, and basic punctuation."
            default:
                return "Invalid input format."
            }
            
        default:
            // Generic error
            return "An error occurred. Please try again."
        }
    }
}

// MARK: - Key Rotation Pattern

extension EncryptionService {
    /// Example: Scheduled key rotation
    func performScheduledKeyRotation() async throws {
        print("Starting key rotation...")
        
        // Rotate the key
        try rotateKey()
        
        // Re-encrypt critical data with new key
        // (In practice, you might re-encrypt sessions gradually)
        
        print("Key rotation complete")
    }
}

// MARK: - Audit Logging Pattern

protocol SecurityAuditable {
    func logSecurityEvent(_ event: SecurityEvent)
}

struct SecurityEvent {
    let timestamp: Date
    let action: String
    let result: Result<String, Error>
    let metadata: [String: Any]
}

// MARK: - Testing Patterns

#if DEBUG
extension EncryptionService {
    /// Example: Testing encryption in development
    static func runSecurityTests() throws {
        let testData = "Test voice transcription data".data(using: .utf8)!
        
        // Test encryption/decryption
        let encrypted = try EncryptionService.shared.encrypt(testData)
        let decrypted = try EncryptionService.shared.decrypt(encrypted)
        
        assert(testData == decrypted, "Encryption round-trip failed")
        
        // Test key rotation
        try EncryptionService.shared.rotateKey()
        
        // Test with new key
        let encrypted2 = try EncryptionService.shared.encrypt(testData)
        let decrypted2 = try EncryptionService.shared.decrypt(encrypted2)
        
        assert(testData == decrypted2, "Encryption with rotated key failed")
        
        print("✅ Security tests passed")
    }
}
#endif