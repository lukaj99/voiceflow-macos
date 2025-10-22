import Foundation
import Combine

/// Modern view model coordinating audio recording and Deepgram transcription
/// Uses secure keychain storage and follows Swift 6 best practices
@MainActor
public class SimpleTranscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var transcriptionText = ""
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0
    @Published public var connectionStatus = "Disconnected"
    @Published public var errorMessage: String?
    @Published public var isConfigured = false
    @Published public var globalInputEnabled = false
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
    
    public func clearTranscription() {
        transcriptionText = ""
        errorMessage = nil
        
        // Reset global text insertion tracking
        hasInsertedGlobalText = false
        
        print("🧹 Transcription cleared")
    }
    
    /// Reconfigure credentials (for settings or troubleshooting)
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
                // Remove any existing interim result before adding final
                let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
                if lines.count > 0 && lines.last?.hasPrefix("[Interim]") == true {
                    // Remove the interim line and add final result
                    let previousLines = lines.dropLast().joined(separator: "\n")
                    transcriptionText = previousLines
                }
                
                // Check for medical terminology and auto-switch model if needed
                autoSwitchModelIfNeeded(for: transcript)
                
                // Handle global text input if enabled
                if globalInputEnabled {
                    // Add proper spacing for global insertion
                    let textToInsert = hasInsertedGlobalText ? " \(transcript)" : transcript
                    let result = await globalTextInputService.insertText(textToInsert)
                    
                    switch result {
                    case .success:
                        hasInsertedGlobalText = true
                        print("📝 Final transcript inserted globally: \(transcript)")
                        // Still add to local transcription for record keeping
                        if !transcriptionText.isEmpty {
                            transcriptionText += " "
                        }
                        transcriptionText += "[Global] \(transcript)"
                    case .accessibilityDenied:
                        errorMessage = "Global input failed: Accessibility permissions required"
                        // Fall back to local display
                        if !transcriptionText.isEmpty {
                            transcriptionText += " "
                        }
                        transcriptionText += transcript
                    case .noActiveTextField:
                        print("⚠️ No active text field found - displaying locally")
                        // Fall back to local display
                        if !transcriptionText.isEmpty {
                            transcriptionText += " "
                        }
                        transcriptionText += transcript
                    case .insertionFailed(let error):
                        errorMessage = "Global input failed: \(error.localizedDescription)"
                        // Fall back to local display
                        if !transcriptionText.isEmpty {
                            transcriptionText += " "
                        }
                        transcriptionText += transcript
                    }
                } else {
                    // Normal local display
                    if !transcriptionText.isEmpty {
                        transcriptionText += " "
                    }
                    transcriptionText += transcript
                    print("📝 Added final transcript: \(transcript)")
                }
            } else {
                // Show interim results immediately for better UX (only locally)
                // Replace the last interim result with the new one
                let lines = transcriptionText.split(separator: "\n", omittingEmptySubsequences: false)
                if lines.count > 0 && lines.last?.hasPrefix("[Interim]") == true {
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
    }
}