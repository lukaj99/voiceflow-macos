import Foundation
import CryptoKit
import Security

/// Provides AES-256-GCM encryption for sensitive data with secure key management
public final class EncryptionService {
    
    // MARK: - Constants
    
    private static let keychainServiceName = "com.voiceflow.encryption"
    private static let keyAlias = "voiceflow-data-key"
    private static let keySize = 32 // 256 bits for AES-256
    private static let nonceSize = 12 // 96 bits for GCM
    private static let tagSize = 16 // 128 bits for GCM
    
    // MARK: - Properties
    
    private let keychain = KeychainManager()
    private var symmetricKey: SymmetricKey?
    private let keyAccessQueue = DispatchQueue(label: "com.voiceflow.encryption.key", attributes: .concurrent)
    
    // MARK: - Singleton
    
    public static let shared = EncryptionService()
    
    private init() {
        loadOrCreateKey()
    }
    
    // MARK: - Public Methods
    
    /// Encrypts data using AES-256-GCM
    /// - Parameter data: The data to encrypt
    /// - Returns: Encrypted data with nonce and tag
    public func encrypt(_ data: Data) throws -> Data {
        let key = try getKey()
        
        // Generate random nonce
        let nonce = AES.GCM.Nonce()
        
        // Encrypt the data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        // Combine nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed("Failed to create combined sealed box")
        }
        
        return combined
    }
    
    /// Decrypts data encrypted with AES-256-GCM
    /// - Parameter encryptedData: The encrypted data (nonce + ciphertext + tag)
    /// - Returns: Decrypted data
    public func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getKey()
        
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // Decrypt the data
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    /// Encrypts a string and returns base64 encoded result
    public func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidInput("Failed to convert string to data")
        }
        
        let encryptedData = try encrypt(data)
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypts a base64 encoded string
    public func decryptString(_ encryptedString: String) throws -> String {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            throw EncryptionError.invalidInput("Invalid base64 string")
        }
        
        let decryptedData = try decrypt(encryptedData)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed("Failed to convert decrypted data to string")
        }
        
        return string
    }
    
    /// Encrypts a Codable object
    public func encryptCodable<T: Codable>(_ object: T) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        return try encrypt(data)
    }
    
    /// Decrypts data to a Codable object
    public func decryptCodable<T: Codable>(_ encryptedData: Data, type: T.Type) throws -> T {
        let decryptedData = try decrypt(encryptedData)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: decryptedData)
    }
    
    /// Rotates the encryption key
    public func rotateKey() throws {
        keyAccessQueue.sync(flags: .barrier) {
            // Generate new key
            let newKey = SymmetricKey(size: .bits256)
            
            // Store new key in keychain
            do {
                try keychain.storeKey(newKey, alias: Self.keyAlias, service: Self.keychainServiceName)
                self.symmetricKey = newKey
            } catch {
                throw EncryptionError.keyRotationFailed(error.localizedDescription)
            }
        }
    }
    
    /// Checks if encryption is properly configured
    public func isConfigured() -> Bool {
        return keyAccessQueue.sync {
            return symmetricKey != nil || (try? keychain.retrieveKey(alias: Self.keyAlias, service: Self.keychainServiceName)) != nil
        }
    }
    
    // MARK: - Private Methods
    
    private func loadOrCreateKey() {
        keyAccessQueue.sync(flags: .barrier) {
            do {
                // Try to load existing key from keychain
                if let existingKey = try keychain.retrieveKey(alias: Self.keyAlias, service: Self.keychainServiceName) {
                    self.symmetricKey = existingKey
                } else {
                    // Generate new key
                    let newKey = SymmetricKey(size: .bits256)
                    try keychain.storeKey(newKey, alias: Self.keyAlias, service: Self.keychainServiceName)
                    self.symmetricKey = newKey
                }
            } catch {
                // Log error but don't crash - encryption will fail on first use
                print("Failed to load or create encryption key: \(error)")
            }
        }
    }
    
    private func getKey() throws -> SymmetricKey {
        return try keyAccessQueue.sync {
            if let key = self.symmetricKey {
                return key
            }
            
            // Try to load from keychain
            if let key = try keychain.retrieveKey(alias: Self.keyAlias, service: Self.keychainServiceName) {
                self.symmetricKey = key
                return key
            }
            
            throw EncryptionError.keyNotFound("Encryption key not found")
        }
    }
}

// MARK: - Encryption Errors

public enum EncryptionError: LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keyNotFound(String)
    case keyRotationFailed(String)
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let message):
            return "Encryption failed: \(message)"
        case .decryptionFailed(let message):
            return "Decryption failed: \(message)"
        case .keyNotFound(let message):
            return "Key not found: \(message)"
        case .keyRotationFailed(let message):
            return "Key rotation failed: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}

// MARK: - Keychain Manager

private final class KeychainManager {
    
    func storeKey(_ key: SymmetricKey, alias: String, service: String) throws {
        // Convert key to data
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Delete existing key if present
        deleteKey(alias: alias, service: service)
        
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: alias,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw EncryptionError.encryptionFailed("Failed to store key in keychain: \(status)")
        }
    }
    
    func retrieveKey(alias: String, service: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: alias,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        switch status {
        case errSecSuccess:
            guard let keyData = dataTypeRef as? Data else {
                throw EncryptionError.decryptionFailed("Invalid key data format")
            }
            return SymmetricKey(data: keyData)
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw EncryptionError.decryptionFailed("Failed to retrieve key from keychain: \(status)")
        }
    }
    
    func deleteKey(alias: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: alias
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Migration Support

extension EncryptionService {
    
    /// Migrates unencrypted data to encrypted format
    public func migrateData<T: Codable>(_ unencryptedData: Data, type: T.Type) throws -> Data {
        let decoder = JSONDecoder()
        let object = try decoder.decode(type, from: unencryptedData)
        return try encryptCodable(object)
    }
    
    /// Checks if data is encrypted (by checking for valid AES-GCM format)
    public func isDataEncrypted(_ data: Data) -> Bool {
        // AES-GCM combined format: nonce (12) + ciphertext (variable) + tag (16)
        // Minimum size is nonce + tag + at least 1 byte of ciphertext
        guard data.count >= Self.nonceSize + Self.tagSize + 1 else {
            return false
        }
        
        // Try to create a sealed box - if it succeeds, data is likely encrypted
        do {
            _ = try AES.GCM.SealedBox(combined: data)
            return true
        } catch {
            return false
        }
    }
}