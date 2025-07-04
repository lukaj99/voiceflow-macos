import Foundation
import Combine

/// Coordinates transcription workflow between audio, Deepgram, and UI state
/// Single Responsibility: Orchestrates the transcription process
@MainActor
public class TranscriptionCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isActivelyTranscribing = false
    @Published public var transcriptionText = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var connectionStatus = "Disconnected"
    @Published public var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let appState: AppState
    private let audioManager: AudioManager
    private let deepgramClient: DeepgramClient
    private let credentialService: SecureCredentialService
    private let textProcessor: TranscriptionTextProcessor
    private let connectionManager: TranscriptionConnectionManager
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        appState: AppState,
        audioManager: AudioManager = AudioManager(),
        deepgramClient: DeepgramClient = DeepgramClient(),
        credentialService: SecureCredentialService = SecureCredentialService(),
        textProcessor: TranscriptionTextProcessor = TranscriptionTextProcessor(),
        connectionManager: TranscriptionConnectionManager = TranscriptionConnectionManager()
    ) {
        self.appState = appState
        self.audioManager = audioManager
        self.deepgramClient = deepgramClient
        self.credentialService = credentialService
        self.textProcessor = textProcessor
        self.connectionManager = connectionManager
        
        setupBindings()
        setupDelegates()
        
        print("🎯 TranscriptionCoordinator initialized")
    }
    
    // MARK: - Public Interface
    
    /// Start transcription workflow
    public func startTranscription() async {
        print("🎯 Starting transcription workflow...")
        
        guard appState.isConfigured else {
            setError("Credentials not configured. Please check settings.")
            return
        }
        
        do {
            // Get API key and validate
            let apiKey = try await credentialService.getDeepgramAPIKey()
            
            // Connect to Deepgram service
            let connected = await connectionManager.connect(apiKey: apiKey, client: deepgramClient)
            guard connected else {
                setError("Failed to connect to transcription service")
                return
            }
            
            // Start audio recording
            try await audioManager.startRecording()
            
            // Update state
            isActivelyTranscribing = true
            appState.startTranscriptionSession()
            clearError()
            
            print("✅ Transcription workflow started successfully")
            
        } catch {
            setError("Failed to start transcription: \(error.localizedDescription)")
            print("❌ Transcription start failed: \(error)")
        }
    }
    
    /// Stop transcription workflow
    public func stopTranscription() {
        print("🎯 Stopping transcription workflow...")
        
        audioManager.stopRecording()
        
        Task {
            await connectionManager.disconnect(client: deepgramClient)
        }
        
        isActivelyTranscribing = false
        audioLevel = 0.0
        connectionStatus = "Disconnected"
        
        appState.stopTranscriptionSession()
        
        print("✅ Transcription workflow stopped")
    }
    
    /// Clear current transcription
    public func clearTranscription() {
        transcriptionText = ""
        appState.clearTranscription()
        clearError()
        
        print("🧹 Transcription cleared")
    }
    
    /// Pause transcription (keeps connection but stops processing)
    public func pauseTranscription() {
        audioManager.pauseRecording()
        print("⏸️ Transcription paused")
    }
    
    /// Resume transcription
    public func resumeTranscription() {
        audioManager.resumeRecording()
        print("▶️ Transcription resumed")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind audio level
        audioManager.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        // Bind connection status
        deepgramClient.$connectionState
            .receive(on: RunLoop.main)
            .map { $0.rawValue }
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // Bind connection errors
        deepgramClient.$connectionError
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Sync audio level to app state
        $audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.appState.updateAudioLevel(level)
            }
            .store(in: &cancellables)
        
        // Sync connection status to app state
        $connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if let connectionStatus = ConnectionStatus(rawValue: status) {
                    self.appState.setConnectionStatus(connectionStatus)
                }
            }
            .store(in: &cancellables)
        
        print("🔗 TranscriptionCoordinator bindings established")
    }
    
    private func setupDelegates() {
        audioManager.delegate = self
        deepgramClient.delegate = self
        print("👥 TranscriptionCoordinator delegates configured")
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        appState.setError(message)
    }
    
    private func clearError() {
        errorMessage = nil
        appState.setError(nil)
    }
}

// MARK: - AudioManagerDelegate

extension TranscriptionCoordinator: AudioManagerDelegate {
    
    nonisolated public func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data) {
        Task { @MainActor in
            deepgramClient.sendAudioData(data)
        }
    }
}

// MARK: - DeepgramClientDelegate

extension TranscriptionCoordinator: DeepgramClientDelegate {
    
    nonisolated public func deepgramClient(_ client: DeepgramClient, didReceiveTranscript transcript: String, isFinal: Bool) {
        Task { @MainActor in
            let processedText = await textProcessor.processTranscript(transcript, isFinal: isFinal)
            
            if isFinal {
                // Add final transcript to accumulated text
                if !transcriptionText.isEmpty {
                    transcriptionText += " "
                }
                transcriptionText += processedText
                
                // Update app state
                appState.updateTranscription(processedText, isFinal: true)
                
                print("📝 Final transcript processed: \(processedText)")
            } else {
                // Handle interim results (could show in separate UI element)
                print("💭 Interim transcript: \(processedText)")
            }
        }
    }
}