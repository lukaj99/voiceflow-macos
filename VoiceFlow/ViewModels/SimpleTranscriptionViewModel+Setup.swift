import Foundation
import Combine

// MARK: - Setup & Initialization Extension

extension SimpleTranscriptionViewModel {

    func setupBindings() {
        // Bind audio level from AudioManager
        audioManager.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)

        // Bind connection status from enhanced DeepgramClient
        deepgramClient.$connectionState
            .receive(on: RunLoop.main)
            .map { $0.rawValue }
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        // Bind connection errors from DeepgramClient
        deepgramClient.$connectionError
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)

        print("🔗 Enhanced bindings established")
    }

    func setupDelegates() {
        audioManager.delegate = self
        deepgramClient.delegate = self
        print("👥 Delegates configured")
    }

    /// Initialize credentials on app startup
    func initializeCredentials() async {
        do {
            // Perform keychain health check first
            let isHealthy = await credentialService.performHealthCheck()

            guard isHealthy else {
                errorMessage = "Keychain access issue. Please check app permissions."
                isConfigured = false
                return
            }

            // Try to configure from environment first (for development/CI)
            do {
                try await credentialService.configureFromEnvironment()
                print("🔐 Credentials configured from environment")
            } catch {
                // Environment configuration failed, user needs to configure manually
                print("ℹ️ No environment credentials found, user configuration required")
            }

            // Verify configuration status
            await checkCredentialStatus()

            print("🔐 Credentials initialized: \(isConfigured ? "✅ Configured" : "❌ Requires user configuration")")
        }
    }
}
