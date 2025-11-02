import Foundation

/// Comprehensive error system for VoiceFlow application
/// Provides structured error handling with user-friendly messages and recovery actions
public enum VoiceFlowError: LocalizedError, Sendable, Hashable {

    // MARK: - Audio Errors

    case microphonePermissionDenied
    case audioDeviceUnavailable
    case audioConfigurationFailed(String)
    case audioRecordingFailed(String)
    case audioProcessingError(String)

    // MARK: - Transcription Errors

    case transcriptionServiceUnavailable
    case transcriptionConnectionFailed(String)
    case transcriptionTimeout
    case transcriptionApiKeyInvalid
    case transcriptionQuotaExceeded
    case transcriptionFormatUnsupported(String)

    // MARK: - Credential Errors

    case credentialNotFound(String)
    case credentialInvalid(String)
    case keychainAccessDenied
    case credentialStorageFailed(String)
    case credentialValidationFailed(String)

    // MARK: - Network Errors

    case networkUnavailable
    case networkTimeout
    case serverError(Int, String)
    case apiRateLimitExceeded
    case invalidServerResponse

    // MARK: - File System Errors

    case fileNotFound(String)
    case fileAccessDenied(String)
    case fileCorrupted(String)
    case exportFailed(String)
    case storageSpaceInsufficient

    // MARK: - Configuration Errors

    case configurationMissing(String)
    case configurationInvalid(String)
    case languageNotSupported(String)
    case modelNotAvailable(String)

    // MARK: - Security Errors

    case securityThreatDetected(String)
    case accessibilityPermissionDenied
    case unauthorizedAccess(String)
    case dataValidationFailed(String)

    // MARK: - LLM Processing Errors

    case llmProcessingFailed(String)
    case llmAPIKeyInvalid(String)
    case llmServiceUnavailable
    case llmQuotaExceeded(String)
    case llmNetworkError(String)
    case llmResponseInvalid

    // MARK: - System Errors

    case memoryLimitExceeded
    case systemResourceUnavailable(String)
    case applicationStateCorrupted
    case unexpectedError(String)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        // Audio Errors
        case .microphonePermissionDenied:
            return "Microphone access is required for voice transcription. Please grant microphone permissions in System Settings > Privacy & Security > Microphone."

        case .audioDeviceUnavailable:
            return "No audio input device available. Please check that a microphone is connected and working."

        case .audioConfigurationFailed(let details):
            return "Failed to configure audio settings: \(details)"

        case .audioRecordingFailed(let details):
            return "Audio recording failed: \(details)"

        case .audioProcessingError(let details):
            return "Audio processing error: \(details)"

        // Transcription Errors
        case .transcriptionServiceUnavailable:
            return "Transcription service is currently unavailable. Please check your internet connection and try again."

        case .transcriptionConnectionFailed(let details):
            return "Failed to connect to transcription service: \(details)"

        case .transcriptionTimeout:
            return "Transcription request timed out. Please check your internet connection and try again."

        case .transcriptionApiKeyInvalid:
            return "API key is invalid or expired. Please check your credentials in Settings."

        case .transcriptionQuotaExceeded:
            return "Transcription quota exceeded. Please check your account limits or upgrade your plan."

        case .transcriptionFormatUnsupported(let format):
            return "Audio format '\(format)' is not supported for transcription."

        // LLM Processing Errors
        case .llmProcessingFailed(let details):
            return "LLM post-processing failed: \(details)"

        case .llmAPIKeyInvalid(let provider):
            return "\(provider) API key is invalid or expired. Please check your credentials in Settings."

        case .llmServiceUnavailable:
            return "LLM service is currently unavailable. Please try again later."

        case .llmQuotaExceeded(let provider):
            return "\(provider) quota exceeded. Please check your account limits or upgrade your plan."

        case .llmNetworkError(let details):
            return "LLM network error: \(details)"

        case .llmResponseInvalid:
            return "Invalid response from LLM service. Please try again."

    // Credential Errors
        case .credentialNotFound(let credential):
            return "\(credential) not found. Please configure your credentials in Settings."

        case .credentialInvalid(let details):
            return "Invalid credentials: \(details)"

        case .keychainAccessDenied:
            return "Unable to access secure storage. Please check app permissions and try restarting the app."

        case .credentialStorageFailed(let details):
            return "Failed to store credentials securely: \(details)"

        case .credentialValidationFailed(let details):
            return "Credential validation failed: \(details)"

        // Network Errors
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."

        case .networkTimeout:
            return "Network request timed out. Please check your internet connection and try again."

        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"

        case .apiRateLimitExceeded:
            return "API rate limit exceeded. Please wait a moment before trying again."

        case .invalidServerResponse:
            return "Received invalid response from server. Please try again."

        // File System Errors
        case .fileNotFound(let filename):
            return "File not found: \(filename)"

        case .fileAccessDenied(let filename):
            return "Access denied to file: \(filename)"

        case .fileCorrupted(let filename):
            return "File is corrupted or unreadable: \(filename)"

        case .exportFailed(let details):
            return "Export failed: \(details)"

        case .storageSpaceInsufficient:
            return "Insufficient storage space. Please free up space and try again."

        // Configuration Errors
        case .configurationMissing(let component):
            return "Missing configuration for \(component). Please check Settings."

        case .configurationInvalid(let details):
            return "Invalid configuration: \(details)"

        case .languageNotSupported(let language):
            return "Language '\(language)' is not supported for transcription."

        case .modelNotAvailable(let model):
            return "Transcription model '\(model)' is not available."

        // Security Errors
        case .securityThreatDetected(let threat):
            return "Security threat detected: \(threat). Input has been blocked for safety."

        case .accessibilityPermissionDenied:
            return "Accessibility permissions required for global text input. Please grant permissions in System Settings > Privacy & Security > Accessibility."

        case .unauthorizedAccess(let resource):
            return "Unauthorized access to \(resource)."

        case .dataValidationFailed(let details):
            return "Data validation failed: \(details)"

        // System Errors
        case .memoryLimitExceeded:
            return "Memory limit exceeded. Please restart the app or reduce audio session length."

        case .systemResourceUnavailable(let resource):
            return "System resource unavailable: \(resource)"

        case .applicationStateCorrupted:
            return "Application state is corrupted. Please restart the app."

        case .unexpectedError(let details):
            return "An unexpected error occurred: \(details)"
        }
    }

    // MARK: - Recovery Suggestions

    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Go to System Settings > Privacy & Security > Microphone and enable access for VoiceFlow."

        case .audioDeviceUnavailable:
            return "Check that your microphone is connected and not being used by another application."

        case .transcriptionApiKeyInvalid:
            return "Go to Settings and enter a valid API key, or contact support if you believe this is an error."

        case .networkUnavailable:
            return "Check your Wi-Fi or cellular connection and try again."

        case .credentialNotFound:
            return "Go to Settings and configure your API credentials."

        case .accessibilityPermissionDenied:
            return "Go to System Settings > Privacy & Security > Accessibility and enable access for VoiceFlow."

        case .applicationStateCorrupted:
            return "Restart the application to reset the internal state."

        case .storageSpaceInsufficient:
            return "Free up disk space by deleting unnecessary files or moving data to external storage."

        default:
            return "If the problem persists, please contact support with the error details."
        }
    }

    // MARK: - Error Categories

    public var category: ErrorCategory {
        switch self {
        case .microphonePermissionDenied, .audioDeviceUnavailable, .audioConfigurationFailed,
             .audioRecordingFailed, .audioProcessingError:
            return .audio

        case .transcriptionServiceUnavailable, .transcriptionConnectionFailed, .transcriptionTimeout,
             .transcriptionApiKeyInvalid, .transcriptionQuotaExceeded, .transcriptionFormatUnsupported:
            return .transcription

        case .llmProcessingFailed, .llmAPIKeyInvalid, .llmServiceUnavailable, .llmQuotaExceeded,
             .llmNetworkError, .llmResponseInvalid:
            return .transcription

        case .credentialNotFound, .credentialInvalid, .keychainAccessDenied, .credentialStorageFailed,
             .credentialValidationFailed:
            return .credentials

        case .networkUnavailable, .networkTimeout, .serverError, .apiRateLimitExceeded,
             .invalidServerResponse:
            return .network

        case .fileNotFound, .fileAccessDenied, .fileCorrupted, .exportFailed, .storageSpaceInsufficient:
            return .fileSystem

        case .configurationMissing, .configurationInvalid, .languageNotSupported, .modelNotAvailable:
            return .configuration

        case .securityThreatDetected, .accessibilityPermissionDenied, .unauthorizedAccess,
             .dataValidationFailed:
            return .security

        case .memoryLimitExceeded, .systemResourceUnavailable, .applicationStateCorrupted,
             .unexpectedError:
            return .system
        }
    }

    // MARK: - Severity Levels

    public var severity: ErrorSeverity {
        switch self {
        case .securityThreatDetected, .unauthorizedAccess, .applicationStateCorrupted:
            return .critical

        case .microphonePermissionDenied, .transcriptionApiKeyInvalid, .credentialNotFound,
             .networkUnavailable, .accessibilityPermissionDenied:
            return .high

        case .audioDeviceUnavailable, .transcriptionServiceUnavailable, .keychainAccessDenied,
             .fileAccessDenied, .configurationMissing:
            return .medium

        case .transcriptionTimeout, .networkTimeout, .fileNotFound, .languageNotSupported:
            return .low

        default:
            return .medium
        }
    }

    // MARK: - User Action Required

    public var requiresUserAction: Bool {
        switch self {
        case .microphonePermissionDenied, .transcriptionApiKeyInvalid, .credentialNotFound,
             .accessibilityPermissionDenied, .configurationMissing:
            return true
        default:
            return false
        }
    }

    // MARK: - Retry Eligibility

    public var canRetry: Bool {
        switch self {
        case .transcriptionTimeout, .networkTimeout, .networkUnavailable, .serverError,
             .transcriptionServiceUnavailable:
            return true
        case .microphonePermissionDenied, .transcriptionApiKeyInvalid, .credentialInvalid,
             .securityThreatDetected, .applicationStateCorrupted:
            return false
        default:
            return true
        }
    }
}

// MARK: - Supporting Types

public enum ErrorCategory: String, CaseIterable, Sendable, Codable {
    case audio = "Audio"
    case transcription = "Transcription"
    case credentials = "Credentials"
    case network = "Network"
    case fileSystem = "File System"
    case configuration = "Configuration"
    case security = "Security"
    case system = "System"

    public var icon: String {
        switch self {
        case .audio: return "mic.slash"
        case .transcription: return "text.bubble"
        case .credentials: return "key"
        case .network: return "wifi.slash"
        case .fileSystem: return "folder"
        case .configuration: return "gear"
        case .security: return "shield"
        case .system: return "exclamationmark.triangle"
        }
    }
}

public enum ErrorSeverity: String, CaseIterable, Sendable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    public var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }

    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}
