import Foundation
import Combine

/// Modern, clean ViewModel following SOLID principles
/// Single Responsibility: Coordinates UI state with business logic services
@MainActor
public class MainTranscriptionViewModel: ObservableObject {

    // MARK: - Published UI State

    @Published public var displayText = ""
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0
    @Published public var connectionStatus = "Disconnected"
    @Published public var errorMessage: String?
    @Published public var isConfigured = false
    @Published public var globalInputEnabled = false
    @Published public var selectedModel: DeepgramModel = .general

    // MARK: - Computed Properties

    public var canStartRecording: Bool {
        isConfigured && connectionStatus == "Connected" && !isRecording
    }

    public var canStopRecording: Bool {
        isRecording
    }

    public var hasContent: Bool {
        !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Services (Dependency Injection)

    private let appState: AppState
    private let transcriptionCoordinator: TranscriptionCoordinator
    private let credentialManager: CredentialManager
    private let globalInputCoordinator: GlobalTextInputCoordinator
    private let textProcessor: TranscriptionTextProcessor

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        appState: AppState = AppState(),
        transcriptionCoordinator: TranscriptionCoordinator? = nil,
        credentialManager: CredentialManager? = nil,
        globalInputCoordinator: GlobalTextInputCoordinator? = nil,
        textProcessor: TranscriptionTextProcessor? = nil
    ) {
        self.appState = appState
        self.textProcessor = textProcessor ?? TranscriptionTextProcessor(
            llmService: LLMPostProcessingService(),
            appState: appState
        )

        // Initialize coordinators with dependency injection
        self.credentialManager = credentialManager ?? CredentialManager(appState: appState)
        self.globalInputCoordinator = globalInputCoordinator ?? GlobalTextInputCoordinator(appState: appState)
        self.transcriptionCoordinator = transcriptionCoordinator ?? TranscriptionCoordinator(
            appState: appState,
            textProcessor: textProcessor,
            connectionManager: TranscriptionConnectionManager()
        )

        setupBindings()

        print("🎯 MainTranscriptionViewModel initialized with SOLID architecture")
    }

    // MARK: - Public Interface

    /// Start transcription workflow
    public func startRecording() async {
        await transcriptionCoordinator.startTranscription()
        globalInputCoordinator.resetSession()
    }

    /// Stop transcription workflow
    public func stopRecording() {
        transcriptionCoordinator.stopTranscription()
    }

    /// Clear current transcription
    public func clearTranscription() {
        transcriptionCoordinator.clearTranscription()
        displayText = ""
        globalInputCoordinator.resetSession()
    }

    /// Configure API key
    public func configureAPIKey(_ apiKey: String) async {
        await credentialManager.configureAPIKey(apiKey)
    }

    /// Configure from environment
    public func configureFromEnvironment() async {
        await credentialManager.configureFromEnvironment()
    }

    /// Enable global text input
    public func enableGlobalInput() {
        globalInputCoordinator.enableGlobalInput()
    }

    /// Disable global text input
    public func disableGlobalInput() {
        globalInputCoordinator.disableGlobalInput()
    }

    /// Change transcription model
    public func setModel(_ model: DeepgramModel) {
        selectedModel = model
        // The actual model setting would be handled by the transcription coordinator
        print("🧠 Model changed to: \(model.displayName)")
    }

    /// Get available models
    public func getAvailableModels() -> [DeepgramModel] {
        return DeepgramModel.allCases
    }

    /// Perform health check
    public func performHealthCheck() async {
        await credentialManager.performHealthCheck()
    }

    /// Check credential status
    public func checkCredentialStatus() async {
        await credentialManager.validateStoredCredentials()
    }

    /// Get processing statistics
    public func getProcessingStatistics() async -> TranscriptionProcessingStatistics {
        return await textProcessor.getProcessingStatistics()
    }

    /// Get global input statistics
    public func getGlobalInputStatistics() -> InsertionStatistics {
        return globalInputCoordinator.getInsertionStatistics()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind transcription coordinator state
        transcriptionCoordinator.$transcriptionText
            .receive(on: RunLoop.main)
            .assign(to: \.displayText, on: self)
            .store(in: &cancellables)

        transcriptionCoordinator.$isActivelyTranscribing
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)

        transcriptionCoordinator.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)

        transcriptionCoordinator.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        transcriptionCoordinator.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)

        // Bind credential manager state
        credentialManager.$isConfigured
            .receive(on: RunLoop.main)
            .assign(to: \.isConfigured, on: self)
            .store(in: &cancellables)

        // Bind global input coordinator state
        globalInputCoordinator.$isEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.globalInputEnabled, on: self)
            .store(in: &cancellables)

        // Handle transcription text updates for global input
        transcriptionCoordinator.$transcriptionText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                // If global input is enabled, handle text insertion
                if self.globalInputEnabled {
                    Task {
                        // This would be triggered by the transcription coordinator
                        // when new final text is available
                    }
                }
            }
            .store(in: &cancellables)

        print("🔗 MainTranscriptionViewModel bindings established")
    }
}

// MARK: - Preview Support

#if DEBUG
extension MainTranscriptionViewModel {
    /// Create instance for SwiftUI previews
    public static func preview() -> MainTranscriptionViewModel {
        let appState = AppState()
        return MainTranscriptionViewModel(appState: appState)
    }
}
#endif
