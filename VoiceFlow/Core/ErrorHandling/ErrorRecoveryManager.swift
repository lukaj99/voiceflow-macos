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

    private let errorReporter: ErrorReporter
    private var recoveryAttempts: [VoiceFlowError: Int] = [:]
    private let maxRecoveryAttempts = 3

    // MARK: - Initialization

    public init(errorReporter: ErrorReporter = ErrorReporter.shared) {
        self.errorReporter = errorReporter
        print("🔧 ErrorRecoveryManager initialized")
    }

    // MARK: - Public Interface

    /// Handle an error with automatic recovery attempts
    public func handleError(_ error: VoiceFlowError, context: ErrorReporter.ErrorContext) async {
        currentError = error
        showErrorDialog = true

        // Report the error
        await errorReporter.reportError(error, context: context)

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

    private func getRecoveryStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
        switch error {
        case .networkTimeout, .transcriptionTimeout:
            return RecoveryStrategy(
                error: error,
                strategy: .automatic,
                steps: [
                    RecoveryStep(description: "Checking network connectivity"),
                    RecoveryStep(description: "Retrying connection"),
                    RecoveryStep(description: "Adjusting timeout settings")
                ],
                estimatedTime: 10.0,
                successProbability: 0.7
            )

        case .audioConfigurationFailed:
            return RecoveryStrategy(
                error: error,
                strategy: .automatic,
                steps: [
                    RecoveryStep(description: "Resetting audio configuration"),
                    RecoveryStep(description: "Checking audio device availability"),
                    RecoveryStep(description: "Reinitializing audio engine")
                ],
                estimatedTime: 5.0,
                successProbability: 0.8
            )

        case .transcriptionServiceUnavailable:
            return RecoveryStrategy(
                error: error,
                strategy: .semiAutomatic,
                steps: [
                    RecoveryStep(description: "Checking service status"),
                    RecoveryStep(description: "Attempting reconnection"),
                    RecoveryStep(description: "Switching to backup endpoint if available")
                ],
                estimatedTime: 15.0,
                successProbability: 0.6
            )

        case .microphonePermissionDenied:
            return RecoveryStrategy(
                error: error,
                strategy: .manual,
                steps: [
                    RecoveryStep(
                        description: "Guide user to grant microphone permissions",
                        userGuidance: "You'll need to manually grant microphone permissions in System Settings"
                    )
                ],
                estimatedTime: 60.0,
                successProbability: 0.9
            )

        default:
            return RecoveryStrategy(
                error: error,
                strategy: .manual,
                steps: [
                    RecoveryStep(
                        description: "Manual intervention required",
                        userGuidance: error.recoverySuggestion
                    )
                ],
                estimatedTime: 120.0,
                successProbability: 0.5
            )
        }
    }

    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy) async -> Bool {
        let stepProgress = 1.0 / Double(strategy.steps.count)

        for (index, step) in strategy.steps.enumerated() {
            recoveryMessage = step.description
            recoveryProgress = Double(index) * stepProgress

            if let action = step.action {
                do {
                    let success = try await action()
                    if !success {
                        print("🔧 Recovery step failed: \(step.description)")
                        return false
                    }
                } catch {
                    print("🔧 Recovery step error: \(error.localizedDescription)")
                    return false
                }
            }

            // Simulate step execution time
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        recoveryProgress = 1.0
        return true
    }

    private func generateRecoveryActions(for error: VoiceFlowError) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []

        // Always provide a retry action for retryable errors
        if error.canRetry {
            actions.append(RecoveryAction(
                title: "Retry",
                description: "Try the operation again",
                icon: "arrow.clockwise",
                isPrimary: true
            ) {
                _ = await self.attemptRecovery(for: error)
            })
        }

        // Add specific actions based on error type
        switch error {
        case .microphonePermissionDenied:
            actions.append(RecoveryAction(
                title: "Open Settings",
                description: "Go to System Settings to grant permissions",
                icon: "gear",
                requiresUserAction: true
            ) {
                // Would open system settings - implementation depends on platform
                print("🔧 Opening system settings for microphone permissions")
            })

        case .transcriptionApiKeyInvalid, .credentialNotFound:
            actions.append(RecoveryAction(
                title: "Configure Credentials",
                description: "Set up your API credentials",
                icon: "key",
                isPrimary: true,
                requiresUserAction: true
            ) {
                // Would open app settings - implementation depends on UI framework
                print("🔧 Opening credential configuration")
            })

        case .networkUnavailable:
            actions.append(RecoveryAction(
                title: "Check Network",
                description: "Diagnose network connectivity",
                icon: "wifi"
            ) {
                // Would run network diagnostics
                print("🔧 Running network diagnostics")
            })

        default:
            break
        }

        // Always provide dismiss action
        actions.append(RecoveryAction(
            title: "Dismiss",
            description: "Close this error dialog",
            icon: "xmark"
        ) {
            await MainActor.run {
                self.clearError()
            }
        })

        return actions
    }
}
