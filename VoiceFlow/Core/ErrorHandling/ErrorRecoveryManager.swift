import Foundation
import Combine

/// Automated error recovery and user guidance system
/// Single Responsibility: Error recovery strategies and user assistance
@MainActor
public class ErrorRecoveryManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var currentError: VoiceFlowError?
    @Published public var isRecovering = false
    @Published public var recoveryProgress: Double = 0.0
    @Published public var recoveryMessage: String?
    @Published public var showErrorDialog = false
    @Published public var availableActions: [RecoveryAction] = []

    // MARK: - Types

    public struct RecoveryAction: Identifiable, Sendable {
        public let id = UUID()
        public let title: String
        public let description: String
        public let icon: String
        public let isPrimary: Bool
        public let requiresUserAction: Bool
        public let action: @Sendable () async -> Void

        public init(
            title: String,
            description: String,
            icon: String,
            isPrimary: Bool = false,
            requiresUserAction: Bool = false,
            action: @escaping @Sendable () async -> Void
        ) {
            self.title = title
            self.description = description
            self.icon = icon
            self.isPrimary = isPrimary
            self.requiresUserAction = requiresUserAction
            self.action = action
        }
    }

    public struct RecoveryStrategy {
        public let error: VoiceFlowError
        public let strategy: RecoveryType
        public let steps: [RecoveryStep]
        public let estimatedTime: TimeInterval
        public let successProbability: Double

        public init(
            error: VoiceFlowError,
            strategy: RecoveryType,
            steps: [RecoveryStep],
            estimatedTime: TimeInterval,
            successProbability: Double
        ) {
            self.error = error
            self.strategy = strategy
            self.steps = steps
            self.estimatedTime = estimatedTime
            self.successProbability = successProbability
        }
    }

    public enum RecoveryType {
        case automatic
        case semiAutomatic
        case manual
    }

    public struct RecoveryStep {
        public let description: String
        public let action: (@MainActor () async throws -> Bool)?
        public let userGuidance: String?

        public init(
            description: String,
            action: (@MainActor () async throws -> Bool)? = nil,
            userGuidance: String? = nil
        ) {
            self.description = description
            self.action = action
            self.userGuidance = userGuidance
        }
    }

    // MARK: - Dependencies

    private let errorReporter: any ErrorReporting
    private var recoveryAttempts: [VoiceFlowError: Int] = [:]
    private let maxRecoveryAttempts = 3

    // MARK: - Initialization

    public init(errorReporter: any ErrorReporting = ErrorReporter.shared) {
        self.errorReporter = errorReporter
        print("🔧 ErrorRecoveryManager initialized")
    }

    // MARK: - Public Interface

    /// Handle an error with automatic recovery attempts
    public func handleError(_ error: VoiceFlowError, context: ErrorReporter.ErrorContext) async {
        currentError = error
        showErrorDialog = true

        // Report the error
        await errorReporter.reportError(error, context: context, userActions: [], stackTrace: nil)

        // Generate recovery actions
        availableActions = generateRecoveryActions(for: error)

        // Attempt automatic recovery if applicable
        if shouldAttemptAutomaticRecovery(for: error) {
            await attemptAutomaticRecovery(for: error)
        }

        print("🔧 Handling error: \(error.category.rawValue) - \(error.errorDescription ?? "Unknown")")
    }

    /// Attempt recovery for a specific error
    public func attemptRecovery(for error: VoiceFlowError) async -> Bool {
        guard !isRecovering else { return false }

        let attempts = recoveryAttempts[error, default: 0]
        guard attempts < maxRecoveryAttempts else {
            print("🔧 Max recovery attempts reached for error: \(error)")
            return false
        }

        recoveryAttempts[error] = attempts + 1

        isRecovering = true
        recoveryProgress = 0.0
        recoveryMessage = "Attempting to recover from error..."

        defer {
            isRecovering = false
            recoveryProgress = 0.0
            recoveryMessage = nil
        }

        let strategy = getRecoveryStrategy(for: error)
        return await executeRecoveryStrategy(strategy)
    }

    /// Clear current error state
    public func clearError() {
        currentError = nil
        showErrorDialog = false
        availableActions = []
        recoveryMessage = nil
    }

    /// Get recovery suggestions for an error
    public func getRecoverySuggestions(for error: VoiceFlowError) -> [String] {
        switch error {
        case .microphonePermissionDenied:
            return [
                "Open System Settings",
                "Navigate to Privacy & Security > Microphone",
                "Enable VoiceFlow in the list",
                "Restart VoiceFlow if needed"
            ]

        case .transcriptionApiKeyInvalid:
            return [
                "Open VoiceFlow Settings",
                "Go to API Configuration",
                "Enter a valid Deepgram API key",
                "Test the connection"
            ]

        case .networkUnavailable:
            return [
                "Check your internet connection",
                "Try switching between Wi-Fi and cellular",
                "Restart your router if using Wi-Fi",
                "Contact your ISP if problems persist"
            ]

        case .audioDeviceUnavailable:
            return [
                "Check microphone connections",
                "Try a different microphone",
                "Check System Settings > Sound > Input",
                "Restart the app"
            ]

        case .credentialNotFound:
            return [
                "Open Settings in VoiceFlow",
                "Configure API credentials",
                "Ensure credentials are saved properly",
                "Restart the app to reload credentials"
            ]

        default:
            return [
                "Restart the application",
                "Check app permissions",
                "Update to the latest version",
                "Contact support if issues persist"
            ]
        }
    }

    // MARK: - Private Methods

    private func shouldAttemptAutomaticRecovery(for error: VoiceFlowError) -> Bool {
        // Only attempt automatic recovery for certain error types
        switch error {
        case .networkTimeout, .transcriptionTimeout, .transcriptionServiceUnavailable:
            return true
        case .audioConfigurationFailed, .audioRecordingFailed:
            return recoveryAttempts[error, default: 0] < 1 // Try once automatically
        default:
            return false
        }
    }

    private func attemptAutomaticRecovery(for error: VoiceFlowError) async {
        recoveryMessage = "Attempting automatic recovery..."

        let success = await attemptRecovery(for: error)

        if success {
            recoveryMessage = "✅ Recovery successful"
            clearError()
        } else {
            recoveryMessage = "❌ Automatic recovery failed. Manual intervention required."
        }

        // Clear recovery message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.recoveryMessage?.contains("Recovery successful") == true ||
               self.recoveryMessage?.contains("Automatic recovery failed") == true {
                self.recoveryMessage = nil
            }
        }
    }

}
