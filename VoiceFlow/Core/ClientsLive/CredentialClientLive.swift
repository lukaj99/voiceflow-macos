import Dependencies
import Foundation

// MARK: - ServiceType Extension

extension ServiceType {
    /// Map ServiceType to SecureCredentialService.CredentialKey.
    var credentialKey: SecureCredentialService.CredentialKey {
        switch self {
        case .deepgram:
            return .deepgramAPIKey
        case .openai:
            return .openAIAPIKey
        case .claude:
            return .claudeAPIKey
        }
    }
}

// MARK: - CredentialClientLive

/// Live implementation of CredentialClient wrapping SecureCredentialService.
extension CredentialClient {
    /// Live implementation using the actual SecureCredentialService.
    public static var liveValue: CredentialClient {
        // Create a shared credential service instance
        let credentialService = SecureCredentialService()

        return CredentialClient(
            getAPIKey: { serviceType in
                do {
                    return try await credentialService.retrieve(for: serviceType.credentialKey)
                } catch SecureCredentialService.CredentialError.keyNotFound {
                    return nil
                } catch {
                    throw CredentialError.notFound(serviceType)
                }
            },
            setAPIKey: { key, serviceType in
                do {
                    try await credentialService.store(credential: key, for: serviceType.credentialKey)
                } catch {
                    throw CredentialError.saveFailed(serviceType, error)
                }
            },
            deleteAPIKey: { serviceType in
                do {
                    try await credentialService.remove(for: serviceType.credentialKey)
                } catch {
                    throw CredentialError.deleteFailed(serviceType, error)
                }
            },
            hasAPIKey: { serviceType in
                await credentialService.exists(for: serviceType.credentialKey)
            },
            configuredServices: {
                // Return empty - async check not supported in sync context
                []
            },
            validateKeyFormat: { key, serviceType in
                switch serviceType {
                case .deepgram:
                    return key.count >= 32 && key.allSatisfy { isHexDigit($0) }
                case .openai:
                    return key.hasPrefix("sk-") && key.count >= 51
                case .claude:
                    return key.hasPrefix("sk-ant-") && key.count >= 64
                }
            },
            configureFromEnvironment: {
                try await credentialService.configureFromEnvironment()
            },
            performHealthCheck: {
                await credentialService.performHealthCheck()
            }
        )
    }
}

// MARK: - Helper Functions

/// Check if character is a valid hexadecimal digit.
private func isHexDigit(_ char: Character) -> Bool {
    guard char.isASCII else { return false }
    let lowercased = String(char).lowercased()
    guard let firstChar = lowercased.first else { return false }
    return char.isNumber || ("a"..."f").contains(firstChar)
}
