import Foundation

// MARK: - Recovery Strategies Extension

extension ErrorRecoveryManager {

    func getRecoveryStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
        switch error {
        case .networkTimeout, .transcriptionTimeout:
            return createNetworkTimeoutStrategy(for: error)
        case .audioConfigurationFailed:
            return createAudioConfigStrategy(for: error)
        case .transcriptionServiceUnavailable:
            return createServiceUnavailableStrategy(for: error)
        case .microphonePermissionDenied:
            return createPermissionDeniedStrategy(for: error)
        default:
            return createDefaultStrategy(for: error)
        }
    }

    func createNetworkTimeoutStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
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
    }

    func createAudioConfigStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
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
    }

    func createServiceUnavailableStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
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
    }

    func createPermissionDeniedStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
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
    }

    func createDefaultStrategy(for error: VoiceFlowError) -> RecoveryStrategy {
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

    func executeRecoveryStrategy(_ strategy: RecoveryStrategy) async -> Bool {
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

    func generateRecoveryActions(for error: VoiceFlowError) -> [RecoveryAction] {
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
