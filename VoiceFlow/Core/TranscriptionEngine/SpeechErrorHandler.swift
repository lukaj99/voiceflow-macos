import Foundation
import Speech
import Combine
import os.log

/// Handles speech recognition errors following Single Responsibility Principle
@MainActor
public final class SpeechErrorHandler: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "SpeechErrorHandler")
    
    // Publishers
    private let errorSubject = PassthroughSubject<TranscriptionUpdate, Never>()
    public var errorUpdatePublisher: AnyPublisher<TranscriptionUpdate, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    private let recoverySubject = PassthroughSubject<ErrorRecoveryAction, Never>()
    public var recoveryActionPublisher: AnyPublisher<ErrorRecoveryAction, Never> {
        recoverySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
    
    public func handleError(_ error: Error, supportedFeatures: SpeechFeatures) {
        logger.error("Speech recognition error: \(error.localizedDescription)")
        
        let nsError = error as NSError
        let recoveryAction = determineRecoveryAction(for: nsError, supportedFeatures: supportedFeatures)
        
        switch nsError.code {
        case 203: // No speech detected
            handleNoSpeechDetected()
            
        case 209: // Request was cancelled  
            handleRequestCancelled()
            
        case 1110: // Network error (for online recognition)
            handleNetworkError(supportedFeatures: supportedFeatures)
            
        case 216: // Recognition service busy
            handleServiceBusy()
            
        case 301: // Audio recording permission denied
            handleAudioPermissionDenied()
            
        default:
            handleGenericError(nsError)
        }
        
        // Emit recovery action if needed
        if recoveryAction != .none {
            recoverySubject.send(recoveryAction)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleNoSpeechDetected() {
        // Don't treat as error, just continue - this is normal
        logger.debug("No speech detected - continuing recognition")
    }
    
    private func handleRequestCancelled() {
        // Expected when pausing/stopping - don't emit error
        logger.debug("Recognition request cancelled - expected behavior")
    }
    
    private func handleNetworkError(supportedFeatures: SpeechFeatures) {
        logger.warning("Network error occurred during speech recognition")
        
        if supportedFeatures.supportsOnDeviceRecognition {
            // Suggest fallback to offline recognition
            recoverySubject.send(.fallbackToOffline)
        } else {
            // Emit error update
            let errorUpdate = TranscriptionUpdate(
                type: .partial,
                text: "[Network connectivity issue - retrying...]",
                confidence: 0.0
            )
            errorSubject.send(errorUpdate)
        }
    }
    
    private func handleServiceBusy() {
        logger.warning("Speech recognition service is busy")
        
        let errorUpdate = TranscriptionUpdate(
            type: .partial,
            text: "[Speech service temporarily busy - retrying...]",
            confidence: 0.0
        )
        errorSubject.send(errorUpdate)
        
        // Suggest retry after delay
        recoverySubject.send(.retryAfterDelay(2.0))
    }
    
    private func handleAudioPermissionDenied() {
        logger.error("Audio recording permission denied")
        
        let errorUpdate = TranscriptionUpdate(
            type: .partial,
            text: "[Microphone access required for speech recognition]",
            confidence: 0.0
        )
        errorSubject.send(errorUpdate)
        
        recoverySubject.send(.requestPermissions)
    }
    
    private func handleGenericError(_ error: NSError) {
        logger.error("Generic speech recognition error: \(error.localizedDescription)")
        
        let errorMessage = getHumanReadableErrorMessage(for: error)
        let errorUpdate = TranscriptionUpdate(
            type: .partial,
            text: "[\(errorMessage)]",
            confidence: 0.0
        )
        errorSubject.send(errorUpdate)
        
        // For generic errors, suggest restart
        recoverySubject.send(.restart)
    }
    
    private func determineRecoveryAction(for error: NSError, supportedFeatures: SpeechFeatures) -> ErrorRecoveryAction {
        switch error.code {
        case 203, 209: // No speech, cancelled
            return .none
            
        case 1110: // Network error
            return supportedFeatures.supportsOnDeviceRecognition ? .fallbackToOffline : .retryAfterDelay(1.0)
            
        case 216: // Service busy
            return .retryAfterDelay(2.0)
            
        case 301: // Permission denied
            return .requestPermissions
            
        default:
            return .restart
        }
    }
    
    private func getHumanReadableErrorMessage(for error: NSError) -> String {
        switch error.code {
        case 1: return "Recognition not available"
        case 100: return "Speech recognizer initialization failed"
        case 200: return "Audio session error"
        case 201: return "Audio engine error"
        case 202: return "Recognition task error"
        case 204: return "Speech not recognized"
        case 205: return "Recognition timed out"
        case 300: return "Permission required"
        case 1101: return "Invalid audio format"
        case 1102: return "Audio too quiet"
        case 1103: return "Audio too loud"
        default: return "Speech recognition error"
        }
    }
}

// MARK: - Supporting Types

public enum ErrorRecoveryAction {
    case none
    case retryAfterDelay(TimeInterval)
    case fallbackToOffline
    case requestPermissions
    case restart
}

public struct SpeechFeatures {
    public let supportsOnDeviceRecognition: Bool
    public let supportsOfflineRecognition: Bool
    public let supportsPunctuation: Bool
    
    public init(supportsOnDeviceRecognition: Bool, 
                supportsOfflineRecognition: Bool = false, 
                supportsPunctuation: Bool = true) {
        self.supportsOnDeviceRecognition = supportsOnDeviceRecognition
        self.supportsOfflineRecognition = supportsOfflineRecognition
        self.supportsPunctuation = supportsPunctuation
    }
}