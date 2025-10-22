import Foundation
import SwiftUI
import Combine

/// Modern SwiftUI app state using @Observable macro (Swift 5.9+)
/// Replaces traditional ObservableObject patterns with native Swift observation
@Observable
@MainActor
public final class AppState {
    
    // MARK: - Shared Instance
    
    public static let shared = AppState()
    
    // MARK: - Transcription State
    
    /// Current transcription text being built
    public var transcriptionText: String = ""
    
    /// Whether audio recording is currently active
    public var isRecording: Bool = false
    
    /// Current audio input level (0.0 to 1.0)
    public var audioLevel: Float = 0.0
    
    /// Current connection status to transcription service
    public var connectionStatus: ConnectionStatus = .disconnected
    
    /// Any error messages to display to the user
    public var errorMessage: String?
    
    /// Whether the app is currently processing audio
    public var isProcessing: Bool = false
    
    /// Whether global text input is enabled
    public var globalInputEnabled: Bool = false
    
    // MARK: - UI State
    
    /// Currently selected view/tab in the app
    public var selectedView: AppView = .transcription
    
    /// Whether settings sheet is presented
    public var isSettingsPresented: Bool = false
    
    /// Whether onboarding should be shown
    public var shouldShowOnboarding: Bool = false
    
    /// Whether floating widget is visible
    public var isFloatingWidgetVisible: Bool = false
    
    /// Whether floating widget is enabled
    public var isFloatingWidgetEnabled: Bool = true
    
    /// Whether global hotkeys are enabled
    public var isGlobalHotkeysEnabled: Bool = true
    
    /// Current app theme setting
    public var appTheme: AppTheme = .system
    
    // MARK: - Session State
    
    /// Current transcription session
    public var currentSession: TranscriptionSession?
    
    /// Recently completed sessions
    public var recentSessions: [TranscriptionSession] = []
    
    /// Selected language for transcription
    public var selectedLanguage: Language = .english
    
    /// Whether credentials are properly configured
    public var isConfigured: Bool = false
    
    // MARK: - Performance Metrics
    
    /// Current transcription quality metrics
    public var currentMetrics: TranscriptionMetrics?
    
    /// Network latency to transcription service
    public var networkLatency: TimeInterval = 0
    
    // MARK: - LLM Post-Processing State
    
    /// Whether LLM post-processing is enabled
    public var llmPostProcessingEnabled: Bool = false
    
    /// Currently selected LLM provider
    public var selectedLLMProvider: String = "openai"
    
    /// Currently selected LLM model
    public var selectedLLMModel: String = "gpt-4o-mini"
    
    /// Whether LLM is currently processing
    public var isLLMProcessing: Bool = false
    
    /// LLM processing progress (0.0 to 1.0)
    public var llmProcessingProgress: Float = 0.0
    
    /// Last LLM processing error
    public var llmProcessingError: String?
    
    /// Whether any LLM providers are configured
    public var hasLLMProvidersConfigured: Bool = false
    
    /// LLM processing statistics
    public var llmProcessingStats: LLMProcessingStatistics = LLMProcessingStatistics()
    
    // MARK: - Floating Widget Services
    
    /// Floating microphone widget instance
    public var floatingWidget: FloatingMicrophoneWidget?
    
    /// Global hotkey service instance
    public var hotkeyService: GlobalHotkeyService?
    
    // MARK: - Initialization
    
    public init() {
        print("🎯 AppState initialized with modern @Observable pattern")
        loadInitialState()
        setupFloatingServices()
    }
    
    // MARK: - State Management
    
    /// Start a new transcription session
    public func startTranscriptionSession() {
        let session = TranscriptionSession(
            id: UUID(),
            startTime: Date(),
            language: selectedLanguage
        )
        
        currentSession = session
        isRecording = true
        isProcessing = true
        errorMessage = nil
        transcriptionText = ""
        
        print("🎯 Started new transcription session: \(session.id)")
    }
    
    /// Stop the current transcription session
    public func stopTranscriptionSession() {
        guard var session = currentSession else { return }
        
        // Update session with final data
        session = TranscriptionSession(
            id: session.id,
            startTime: session.startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(session.startTime),
            wordCount: transcriptionText.split(separator: " ").count,
            averageConfidence: currentMetrics?.confidence ?? 0.0,
            context: "general",
            transcription: transcriptionText,
            segments: [],
            language: selectedLanguage
        )
        
        // Add to recent sessions
        recentSessions.insert(session, at: 0)
        if recentSessions.count > 50 { // Keep last 50 sessions
            recentSessions.removeLast()
        }
        
        // Reset state
        currentSession = nil
        isRecording = false
        isProcessing = false
        audioLevel = 0.0
        
        print("🎯 Stopped transcription session: \(session.id)")
    }
    
    /// Update transcription text with new content
    public func updateTranscription(_ text: String, isFinal: Bool = false) {
        if isFinal {
            // Add final text to existing transcription
            if !transcriptionText.isEmpty && !text.isEmpty {
                transcriptionText += " "
            }
            transcriptionText += text
        }
        
        // Update current session word count
        if var session = currentSession {
            let wordCount = transcriptionText.split(separator: " ").count
            session = TranscriptionSession(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                duration: Date().timeIntervalSince(session.startTime),
                wordCount: wordCount,
                averageConfidence: session.averageConfidence,
                context: session.context,
                transcription: transcriptionText,
                segments: session.segments,
                metadata: session.metadata,
                language: session.language
            )
            currentSession = session
        }
    }
    
    /// Clear current transcription
    public func clearTranscription() {
        transcriptionText = ""
        errorMessage = nil
        print("🎯 Transcription cleared")
    }
    
    /// Update connection status
    public func setConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        
        if status == .connected {
            errorMessage = nil
        }
    }
    
    /// Set error message
    public func setError(_ message: String?) {
        errorMessage = message
        if message != nil {
            print("🎯 Error set: \(message!)")
        }
    }
    
    /// Update audio level
    public func updateAudioLevel(_ level: Float) {
        audioLevel = max(0.0, min(1.0, level))
    }
    
    /// Update metrics
    public func updateMetrics(_ metrics: TranscriptionMetrics) {
        currentMetrics = metrics
        networkLatency = metrics.latency
    }
    
    // MARK: - LLM State Management
    
    /// Enable LLM post-processing
    public func enableLLMPostProcessing() {
        llmPostProcessingEnabled = true
        llmProcessingError = nil
        print("🤖 LLM post-processing enabled")
    }
    
    /// Disable LLM post-processing
    public func disableLLMPostProcessing() {
        llmPostProcessingEnabled = false
        isLLMProcessing = false
        llmProcessingProgress = 0.0
        llmProcessingError = nil
        print("🤖 LLM post-processing disabled")
    }
    
    /// Update LLM processing status
    public func setLLMProcessing(_ processing: Bool, progress: Float = 0.0) {
        isLLMProcessing = processing
        llmProcessingProgress = progress
        
        if processing {
            llmProcessingError = nil
        }
    }
    
    /// Set LLM processing error
    public func setLLMProcessingError(_ error: String?) {
        llmProcessingError = error
        if error != nil {
            isLLMProcessing = false
            llmProcessingProgress = 0.0
            print("🤖 LLM processing error: \(error!)")
        }
    }
    
    /// Update LLM configuration status
    public func updateLLMConfigurationStatus(_ hasProviders: Bool) {
        hasLLMProvidersConfigured = hasProviders
    }
    
    /// Set selected LLM provider and model
    public func setSelectedLLMProvider(_ provider: String, model: String) {
        selectedLLMProvider = provider
        selectedLLMModel = model
        print("🤖 LLM provider set to \(provider) with model \(model)")
    }
    
    /// Record LLM processing result
    public func recordLLMProcessingResult(success: Bool, processingTime: TimeInterval, improvementScore: Float = 0.0) {
        llmProcessingStats.recordProcessing(
            success: success,
            processingTime: processingTime,
            improvementScore: improvementScore
        )
    }
    
    // MARK: - Configuration State
    
    /// Mark app as configured
    public func setConfigured(_ configured: Bool) {
        isConfigured = configured
        
        if configured {
            shouldShowOnboarding = false
        }
    }
    
    /// Load initial state from storage
    private func loadInitialState() {
        // Load theme preference
        if let themeRaw = UserDefaults.standard.object(forKey: "AppTheme") as? String,
           let theme = AppTheme(rawValue: themeRaw) {
            appTheme = theme
        }
        
        // Load language preference
        if let languageRaw = UserDefaults.standard.object(forKey: "SelectedLanguage") as? String,
           let language = Language(rawValue: languageRaw) {
            selectedLanguage = language
        }
        
        // Check if onboarding should be shown
        shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
        
        print("🎯 Initial state loaded")
    }
    
    /// Save current state to storage
    public func saveState() {
        UserDefaults.standard.set(appTheme.rawValue, forKey: "AppTheme")
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "SelectedLanguage")
        
        if !shouldShowOnboarding {
            UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        }
        
        print("🎯 State saved to UserDefaults")
    }
    
    // MARK: - Computed Properties
    
    /// Whether the app is ready for transcription
    public var isReadyForTranscription: Bool {
        isConfigured && connectionStatus == .connected && !isRecording
    }
    
    /// Current session duration
    public var currentSessionDuration: TimeInterval {
        guard let session = currentSession else { return 0 }
        return Date().timeIntervalSince(session.startTime)
    }
    
    /// Current word count
    public var currentWordCount: Int {
        transcriptionText.split(separator: " ").count
    }
    
    /// Whether there's transcription content
    public var hasTranscriptionContent: Bool {
        !transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Floating Widget Management
    
    /// Setup floating widget and hotkey services
    private func setupFloatingServices() {
        Task { @MainActor in
            setupFloatingWidget()
            setupHotkeys()
            print("🎤 Floating services initialized")
        }
    }
    
    /// Setup floating widget
    private func setupFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }
        
        // We'll need a ViewModel instance - for now create a simple one
        let viewModel = SimpleTranscriptionViewModel()
        floatingWidget = FloatingMicrophoneWidget(viewModel: viewModel)
        
        print("🎤 Floating widget created")
    }
    
    /// Setup global hotkeys
    private func setupHotkeys() {
        guard isGlobalHotkeysEnabled else { return }
        
        hotkeyService = GlobalHotkeyService()
        
        if let widget = floatingWidget {
            hotkeyService?.setFloatingWidget(widget)
        }
        
        print("⌨️ Global hotkeys configured")
    }
    
    /// Show floating widget
    public func showFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }
        
        floatingWidget?.show()
        isFloatingWidgetVisible = true
    }
    
    /// Hide floating widget
    public func hideFloatingWidget() {
        floatingWidget?.hide()
        isFloatingWidgetVisible = false
    }
    
    /// Toggle floating widget visibility
    public func toggleFloatingWidget() {
        if isFloatingWidgetVisible {
            hideFloatingWidget()
        } else {
            showFloatingWidget()
        }
    }
    
    /// Enable floating widget
    public func enableFloatingWidget() {
        guard !isFloatingWidgetEnabled else { return }
        
        isFloatingWidgetEnabled = true
        setupFloatingWidget()
        
        if let widget = floatingWidget {
            hotkeyService?.setFloatingWidget(widget)
        }
        
        print("🎤 Floating widget enabled")
    }
    
    /// Disable floating widget
    public func disableFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }
        
        isFloatingWidgetEnabled = false
        hideFloatingWidget()
        
        print("🎤 Floating widget disabled")
    }
    
    /// Enable global hotkeys
    public func enableGlobalHotkeys() {
        guard !isGlobalHotkeysEnabled else { return }
        
        isGlobalHotkeysEnabled = true
        hotkeyService?.enable()
        
        print("⌨️ Global hotkeys enabled")
    }
    
    /// Disable global hotkeys
    public func disableGlobalHotkeys() {
        guard isGlobalHotkeysEnabled else { return }
        
        isGlobalHotkeysEnabled = false
        hotkeyService?.disable()
        
        print("⌨️ Global hotkeys disabled")
    }
}

// MARK: - Supporting Types

public enum ConnectionStatus: String, CaseIterable, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
    
    public var color: Color {
        switch self {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    public var systemImage: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

public enum AppView: String, CaseIterable, Sendable {
    case transcription = "Transcription"
    case history = "History"
    case settings = "Settings"
    
    public var systemImage: String {
        switch self {
        case .transcription: return "mic.fill"
        case .history: return "clock.fill"
        case .settings: return "gear.fill"
        }
    }
}

public enum AppTheme: String, CaseIterable, Sendable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}



// MARK: - Environment Integration
// Note: For now we'll manage AppState through direct injection
// Environment integration can be added later with proper Swift 6 patterns

// MARK: - Protocol Conformance

extension AppState: LLMProcessingStateManaging {}
