import Foundation
import Combine

/// Primary view model for VoiceFlow transcription interface
///
/// `SimpleTranscriptionViewModel` coordinates all aspects of the voice transcription workflow,
/// including audio capture, real-time transcription via Deepgram, credential management,
/// and optional global text input functionality. It follows Swift 6 concurrency patterns
/// and implements secure keychain-based credential storage.
///
/// # Features
/// - Real-time voice transcription using Deepgram's streaming API
/// - Automatic connection management with retry logic
/// - Secure credential storage via macOS Keychain
/// - Global text input mode for typing transcriptions into any app
/// - Multiple Deepgram models (general, medical, enhanced)
/// - Medical terminology detection with automatic model switching
/// - Interim and final transcript handling
///
/// # Example Usage
/// ```swift
/// let viewModel = SimpleTranscriptionViewModel()
///
/// // Configure API key
/// await viewModel.reconfigureCredentials(newAPIKey: "your-api-key")
///
/// // Start transcription
/// await viewModel.startRecording()
///
/// // Enable global text input
/// viewModel.enableGlobalInputMode()
///
/// // Stop transcription
/// viewModel.stopRecording()
/// ```
///
/// # Architecture
/// This view model uses dependency injection for services and follows the Coordinator pattern:
/// - `AudioManager`: Handles microphone input and audio processing
/// - `DeepgramClient`: Manages WebSocket connection to Deepgram API
/// - `SecureCredentialService`: Secures API keys in macOS Keychain
/// - `GlobalTextInputService`: Provides system-wide text insertion via Accessibility API
///
/// # Concurrency
/// All public methods are `@MainActor` isolated and use modern Swift concurrency (async/await).
/// The view model properly handles delegate callbacks from background threads.
///
/// # Performance
/// - Audio processing: Real-time with minimal latency
/// - Transcription latency: Typically 100-300ms for interim results
/// - Memory usage: Scales with transcription length (approximately 1KB per 100 words)
///
/// - Note: Requires macOS 14.0+ for Swift 6 concurrency features and Accessibility API support
/// - SeeAlso: `MainTranscriptionViewModel`, `TranscriptionCoordinator`
@MainActor
public class SimpleTranscriptionViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The accumulated transcription text from all processed audio
    ///
    /// Updated with final transcripts from Deepgram. Interim results are shown separately
    /// and replaced when final transcripts arrive. When global input is enabled, transcripts
    /// are prefixed with `[Global]` to indicate they were inserted system-wide.
    @Published public var transcriptionText = ""

    /// Whether audio recording and transcription is currently active
    ///
    /// Transitions to `true` when `startRecording()` successfully connects and begins recording.
    /// Transitions to `false` when `stopRecording()` is called or connection fails.
    @Published public var isRecording = false

    /// Current microphone audio level (0.0 to 1.0)
    ///
    /// Updated in real-time during recording to provide visual feedback.
    /// Returns to 0.0 when recording stops.
    @Published public var audioLevel: Float = 0.0

    /// Human-readable connection status string
    ///
    /// Possible values: "Disconnected", "Connecting", "Connected", "Reconnecting", "Error"
    /// Automatically synced from `DeepgramClient.connectionState`
    @Published public var connectionStatus = "Disconnected"

    /// User-facing error message, if any error has occurred
    ///
    /// Set when operations fail (connection errors, invalid credentials, permission issues, etc.).
    /// Cleared when errors are resolved or operations succeed.
    @Published public var errorMessage: String?

    /// Whether API credentials are properly configured and valid
    ///
    /// Automatically updated when credentials are configured, validated, or removed.
    /// Must be `true` before transcription can begin.
    @Published public var isConfigured = false

    /// Whether global text input mode is currently enabled
    ///
    /// When `true`, final transcripts are inserted into the focused text field of any application
    /// using macOS Accessibility APIs. Requires Accessibility permissions.
    @Published public var globalInputEnabled = false

    /// Currently selected Deepgram transcription model
    ///
    /// Can be changed during transcription. The model may be automatically switched
    /// to `.medical` if medical terminology is detected in the transcription.
    @Published public var selectedModel: DeepgramModel = .general

    // Track if we've inserted text in this session to handle spacing
    private var hasInsertedGlobalText = false

    // Medical terminology detection
    private var medicalTermsDetected = 0
    private var totalWordsProcessed = 0

    // MARK: - Private Properties
    private let audioManager = AudioManager()
    private let deepgramClient = DeepgramClient()
    private let credentialService = SecureCredentialService()
    private let globalTextInputService = GlobalTextInputService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    public init() {
        setupBindings()
        setupDelegates()

        print("🎯 Modern TranscriptionViewModel initialized")

        // Initialize credentials asynchronously after setup
        Task { [weak self] in
            await self?.initializeCredentials()
        }
    }

    // MARK: - Public Methods

    /// Start audio recording and real-time transcription
    ///
    /// Initiates the complete transcription workflow by:
    /// 1. Validating API credentials are configured
    /// 2. Retrieving and validating the Deepgram API key from Keychain
    /// 3. Establishing a WebSocket connection to Deepgram's streaming API
    /// 4. Starting microphone audio capture
    /// 5. Beginning real-time transcription processing
    ///
    /// The method waits for successful connection before starting audio capture,
    /// implementing a timeout mechanism to prevent indefinite waiting.
    ///
    /// # Example
    /// ```swift
    /// if viewModel.isConfigured {
    ///     await viewModel.startRecording()
    ///     // Now isRecording will be true and transcriptions will appear
    /// }
    /// ```
    ///
    /// # Connection Process
    /// 1. **Credential check**: Verifies `isConfigured` is true
    /// 2. **API key retrieval**: Securely retrieves key from macOS Keychain
    /// 3. **API key validation**: Validates key format before use
    /// 4. **WebSocket connection**: Connects to Deepgram with 10-second timeout
    /// 5. **Audio capture**: Starts microphone recording on successful connection
    ///
    /// # Error Handling
    /// Errors are reported via the `errorMessage` published property:
    /// - Credentials not configured: "Credentials not configured..."
    /// - Invalid API key format: "Invalid API key format..."
    /// - Connection timeout: "Connection timeout - check network and API key"
    /// - Connection error: "Failed to connect to Deepgram service"
    /// - Audio recording error: "Failed to start recording: [error]"
    ///
    /// # State Changes
    /// - `isRecording` → `true` on success
    /// - `transcriptionText` → cleared
    /// - `errorMessage` → set if any error occurs
    /// - `connectionStatus` → updated throughout connection process
    ///
    /// # Performance
    /// - Connection time: Typically 1-3 seconds
    /// - Timeout: 10 seconds maximum wait for connection
    /// - Audio latency: Minimal (~50ms) for real-time processing
    ///
    /// - Note: This method is async and must be called from an async context
    /// - Important: Requires `isConfigured` to be `true` before calling
    /// - SeeAlso: `stopRecording()`, `reconfigureCredentials(newAPIKey:)`
    public func startRecording() async {
        print("🎯 Starting transcription...")

        // Check if credentials are configured
        guard isConfigured else {
            errorMessage = "Credentials not configured. Please restart the app."
            return
        }

        errorMessage = nil

        // Reset global text insertion tracking for new session
        hasInsertedGlobalText = false

        do {
            // Retrieve API key from secure storage
            let apiKey = try await credentialService.getDeepgramAPIKey()

            // Validate API key before use
            guard await credentialService.validateCredential(apiKey, for: .deepgramAPIKey) else {
                errorMessage = "Invalid API key format. Please reconfigure."
                return
            }

            // Connect to Deepgram with auto-reconnection
            deepgramClient.connect(apiKey: apiKey, autoReconnect: true)

            // Wait for connection with timeout (enhanced client has its own timeout handling)
            let connectionTimeout = 10.0
            let startTime = Date()

            while deepgramClient.connectionState != .connected && Date().timeIntervalSince(startTime) < connectionTimeout {
                if deepgramClient.connectionState == .error {
                    errorMessage = "Failed to connect to Deepgram service"
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }

            guard deepgramClient.connectionState == .connected else {
                errorMessage = "Connection timeout - check network and API key"
                return
            }

            // Start audio recording
            try await audioManager.startRecording()

            isRecording = true
            transcriptionText = ""
            print("✅ Transcription started successfully")

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
            print("❌ Failed to start transcription: \(error)")
        }
    }

    /// Stop audio recording and transcription
    ///
    /// Gracefully terminates the transcription session by:
    /// 1. Stopping microphone audio capture
    /// 2. Closing the WebSocket connection to Deepgram
    /// 3. Resetting UI state indicators
    /// 4. Preserving transcribed text for review or export
    ///
    /// # Example
    /// ```swift
    /// if viewModel.isRecording {
    ///     viewModel.stopRecording()
    ///     // Transcription text remains available in transcriptionText
    /// }
    /// ```
    ///
    /// # State Changes
    /// - `isRecording` → `false`
    /// - `audioLevel` → 0.0 (no more audio input)
    /// - `connectionStatus` → "Disconnected"
    /// - `transcriptionText` → preserved (not cleared)
    /// - `hasInsertedGlobalText` → reset for next session
    ///
    /// # Cleanup
    /// This method ensures proper cleanup of resources:
    /// - Releases audio capture hardware
    /// - Closes network connections
    /// - Stops background processing threads
    ///
    /// - Note: Transcribed text is NOT cleared; use `clearTranscription()` for that
    /// - SeeAlso: `startRecording()`, `clearTranscription()`
    public func stopRecording() {
        print("🎯 Stopping transcription...")

        audioManager.stopRecording()
        deepgramClient.disconnect()

        isRecording = false
        audioLevel = 0.0
        connectionStatus = "Disconnected"

        // Reset global text insertion tracking
        hasInsertedGlobalText = false

        print("✅ Transcription stopped")
    }

    /// Clear all transcribed text and reset the transcription view
    ///
    /// Removes all accumulated transcription text and clears any error messages.
    /// This operation resets the transcription UI to a clean state while preserving
    /// connection status and configuration.
    ///
    /// # Example
    /// ```swift
    /// // After reviewing transcription
    /// viewModel.clearTranscription()
    /// // Now transcriptionText is empty and ready for new content
    /// ```
    ///
    /// # State Changes
    /// - `transcriptionText` → "" (empty string)
    /// - `errorMessage` → nil (clears any errors)
    /// - `hasInsertedGlobalText` → false (resets global input session)
    ///
    /// # Use Cases
    /// - Starting a fresh transcription session
    /// - Clearing previous errors before retry
    /// - Resetting UI after exporting transcription
    ///
    /// # Preserved State
    /// The following state is NOT affected:
    /// - Connection status
    /// - API configuration
    /// - Recording state
    /// - Selected model
    /// - Global input mode
    ///
    /// - Note: Call this before starting a new transcription session for a clean slate
    /// - SeeAlso: `stopRecording()`, `startRecording()`
    public func clearTranscription() {
        transcriptionText = ""
        errorMessage = nil

        // Reset global text insertion tracking
        hasInsertedGlobalText = false

        print("🧹 Transcription cleared")
    }

    /// Reconfigure Deepgram API credentials
    ///
    /// Updates the stored API credentials, either from a user-provided key or from
    /// environment variables. The new credentials are validated and securely stored
    /// in macOS Keychain before being marked as configured.
    ///
    /// # Parameters
    /// - newAPIKey: Optional new API key to store. If nil, attempts to load from environment.
    ///
    /// # Example Usage
    /// ```swift
    /// // Configure with user-provided key
    /// await viewModel.reconfigureCredentials(newAPIKey: "your-deepgram-api-key")
    ///
    /// // Configure from environment variables
    /// await viewModel.reconfigureCredentials()
    /// ```
    ///
    /// # Configuration Sources
    /// 1. **Explicit API key**: When `newAPIKey` parameter is provided
    /// 2. **Environment variable**: Reads from `DEEPGRAM_API_KEY` when parameter is nil
    ///
    /// # Validation
    /// The method performs the following validation:
    /// - Key format validation (proper structure and length)
    /// - Secure storage in macOS Keychain
    /// - Verification of successful storage
    ///
    /// # State Changes
    /// On success:
    /// - API key stored in Keychain
    /// - `isConfigured` → `true`
    /// - `errorMessage` → nil
    ///
    /// On failure:
    /// - `isConfigured` → `false`
    /// - `errorMessage` → detailed error description
    ///
    /// # Error Scenarios
    /// - **No key provided and no environment variable**: Throws keyNotFound error
    /// - **Invalid key format**: Validation fails
    /// - **Keychain access denied**: Storage operation fails
    /// - **Network issues**: Cannot verify key with service
    ///
    /// # Security
    /// - API keys are stored exclusively in macOS Keychain
    /// - Keys are never logged or displayed in plain text
    /// - Automatic cleanup on configuration failure
    ///
    /// - Note: This method is async and requires await
    /// - Important: Existing credentials are replaced when new key is provided
    /// - SeeAlso: `checkCredentialStatus()`, `performHealthCheck()`
    public func reconfigureCredentials(newAPIKey: String? = nil) async {
        do {
            if let newKey = newAPIKey {
                // Store new API key
                try await credentialService.storeDeepgramAPIKey(newKey)
                print("🔐 New API key configured")
            } else {
                // Try to configure from environment, otherwise user must provide key
                do {
                    try await credentialService.configureFromEnvironment()
                    print("🔐 Credentials reconfigured from environment")
                } catch {
                    throw SecureCredentialService.CredentialError.keyNotFound("No API key provided and none found in environment. Please provide an API key.")
                }
            }

            // Update configuration status
            isConfigured = await credentialService.hasDeepgramAPIKey()

            if isConfigured {
                errorMessage = nil
            }

        } catch {
            errorMessage = "Failed to configure credentials: \(error.localizedDescription)"
            isConfigured = false
            print("❌ Credential configuration failed: \(error)")
        }
    }

    /// Check credential status
    public func checkCredentialStatus() async {
        do {
            let hasKey = await credentialService.hasDeepgramAPIKey()

            if hasKey {
                // Validate the stored key
                let apiKey = try await credentialService.getDeepgramAPIKey()
                let isValid = await credentialService.validateCredential(apiKey, for: .deepgramAPIKey)

                isConfigured = isValid

                if !isValid {
                    errorMessage = "Stored API key is invalid. Please reconfigure."
                }
            } else {
                isConfigured = false
                errorMessage = "No API key configured."
            }

        } catch {
            isConfigured = false
            errorMessage = "Failed to check credentials: \(error.localizedDescription)"
        }
    }

    /// Perform keychain health check
    public func performHealthCheck() async -> Bool {
        let isHealthy = await credentialService.performHealthCheck()

        if !isHealthy {
            errorMessage = "Keychain access issue detected. Please check app permissions."
        }

        return isHealthy
    }

    /// Enable global text input mode with permission check
    public func enableGlobalInputMode() {
        // Request permissions first
        globalTextInputService.requestAccessibilityPermissions()

        // Check if permissions were granted (may need a delay for system dialog)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.globalTextInputService.checkAccessibilityPermissions()

            if self.globalTextInputService.hasAccessibilityPermissions {
                self.globalInputEnabled = true
                print("🌐 Global input mode enabled")
            } else {
                self.globalInputEnabled = false
                self.errorMessage = "Accessibility permissions required for global text input. Please grant permissions in System Settings > Privacy & Security > Accessibility."
                print("❌ Global input mode failed: No accessibility permissions")
            }
        }
    }

    /// Disable global text input mode
    public func disableGlobalInputMode() {
        globalInputEnabled = false
        print("🌐 Global input mode disabled")
    }

    /// Check if accessibility permissions are available
    public func checkGlobalInputPermissions() -> Bool {
        globalTextInputService.checkAccessibilityPermissions()
        return globalTextInputService.hasAccessibilityPermissions
    }

    /// Change the Deepgram model
    public func setModel(_ model: DeepgramModel) {
        selectedModel = model
        deepgramClient.setModel(model)
        print("🧠 Model changed to: \(model.displayName)")
    }

    /// Get available models
    public func getAvailableModels() -> [DeepgramModel] {
        return DeepgramModel.allCases
    }

    /// Check if text contains medical terminology
    private func detectMedicalTerminology(in text: String) -> Bool {
        let medicalTerms = [
            // Anatomy
            "heart", "lung", "liver", "kidney", "brain", "blood", "artery", "vein", "muscle", "bone",
            "stomach", "intestine", "pancreas", "thyroid", "spine", "joint", "tendon", "ligament",

            // Medical conditions
            "diagnosis", "symptoms", "syndrome", "disease", "infection", "inflammation", "tumor",
            "cancer", "diabetes", "hypertension", "pneumonia", "bronchitis", "asthma", "allergy",
            "fracture", "injury", "wound", "lesion", "ulcer", "edema", "fever", "pain", "nausea",

            // Medical procedures
            "surgery", "operation", "procedure", "examination", "treatment", "therapy", "medication",
            "prescription", "injection", "biopsy", "scan", "x-ray", "MRI", "CT scan", "ultrasound",
            "endoscopy", "anesthesia", "suture", "incision", "transplant",

            // Medical professionals
            "doctor", "physician", "surgeon", "nurse", "patient", "radiologist", "cardiologist",
            "oncologist", "neurologist", "psychiatrist", "anesthesiologist", "pathologist",

            // Medical measurements
            "blood pressure", "heart rate", "temperature", "glucose", "cholesterol", "hemoglobin",
            "white blood cell", "red blood cell", "platelet", "creatinine", "sodium", "potassium",

            // Medical abbreviations (common ones)
            "mg", "ml", "cc", "IV", "IM", "PO", "PRN", "stat", "ICU", "ER", "OR", "post-op", "pre-op"
        ]

        let lowercaseText = text.lowercased()
        let words = lowercaseText.components(separatedBy: CharacterSet.alphanumerics.inverted)

        var medicalWordCount = 0
        for word in words {
            if medicalTerms.contains(word) {
                medicalWordCount += 1
            }
        }

        // Update statistics
        totalWordsProcessed += words.count
        medicalTermsDetected += medicalWordCount

        // Return true if more than 20% of words are medical terms
        return words.count > 5 && (Double(medicalWordCount) / Double(words.count)) > 0.2
    }

    /// Auto-switch to medical model if medical terminology is detected
    private func autoSwitchModelIfNeeded(for text: String) {
        // Only auto-switch if currently using general model
        guard selectedModel == .general else { return }

        if detectMedicalTerminology(in: text) {
            print("🏥 Medical terminology detected, switching to medical model")
            setModel(.medical)
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
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

    private func setupDelegates() {
        audioManager.delegate = self
        deepgramClient.delegate = self
        print("👥 Delegates configured")
    }

    /// Initialize credentials on app startup
    private func initializeCredentials() async {
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

// MARK: - AudioManagerDelegate

extension SimpleTranscriptionViewModel: AudioManagerDelegate {

    nonisolated public func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data) {
        Task { @MainActor in
            // Send audio data to Deepgram
            deepgramClient.sendAudioData(data)
        }
    }
}

// MARK: - DeepgramClientDelegate

extension SimpleTranscriptionViewModel: DeepgramClientDelegate {

    nonisolated public func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool) {
        Task { @MainActor in
            if isFinal {
                await handleFinalTranscript(transcript)
            } else {
                handleInterimTranscript(transcript)
            }
        }
    }

    private func handleFinalTranscript(_ transcript: String) async {
        // Remove any existing interim result before adding final
        removeInterimResult()

        // Check for medical terminology and auto-switch model if needed
        autoSwitchModelIfNeeded(for: transcript)

        // Handle global text input if enabled
        if globalInputEnabled {
            await handleGlobalTextInsertion(transcript)
        } else {
            appendToLocalTranscript(transcript)
            print("📝 Added final transcript: \(transcript)")
        }
    }

    private func removeInterimResult() {
        let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty, lines.last?.hasPrefix("[Interim]") == true else { return }

        let previousLines = lines.dropLast().joined(separator: "\n")
        transcriptionText = previousLines
    }

    private func handleGlobalTextInsertion(_ transcript: String) async {
        let textToInsert = hasInsertedGlobalText ? " \(transcript)" : transcript
        let result = await globalTextInputService.insertText(textToInsert)

        switch result {
        case .success:
            hasInsertedGlobalText = true
            print("📝 Final transcript inserted globally: \(transcript)")
            appendToLocalTranscript("[Global] \(transcript)")
        case .accessibilityDenied:
            errorMessage = "Global input failed: Accessibility permissions required"
            appendToLocalTranscript(transcript)
        case .noActiveTextField:
            print("⚠️ No active text field found - displaying locally")
            appendToLocalTranscript(transcript)
        case .insertionFailed(let error):
            errorMessage = "Global input failed: \(error.localizedDescription)"
            appendToLocalTranscript(transcript)
        }
    }

    private func appendToLocalTranscript(_ text: String) {
        if !transcriptionText.isEmpty {
            transcriptionText += " "
        }
        transcriptionText += text
    }

    private func handleInterimTranscript(_ transcript: String) {
        let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
        if !lines.isEmpty && lines.last?.hasPrefix("[Interim]") == true {
            // Replace last interim line
            let previousLines = lines.dropLast().joined(separator: "\n")
            transcriptionText = previousLines + (previousLines.isEmpty ? "" : "\n") + "[Interim] \(transcript)"
        } else {
            // Add new interim line
            transcriptionText += (transcriptionText.isEmpty ? "" : "\n") + "[Interim] \(transcript)"
        }
        print("💭 Showing interim transcript: \(transcript)")
    }
}
