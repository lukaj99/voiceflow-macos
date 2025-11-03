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

    /// Start a new transcription session with automatic state initialization.
    ///
    /// Creates a new transcription session with current settings and prepares the app
    /// for audio recording and real-time transcription. This method automatically:
    /// - Creates a new session with unique identifier
    /// - Initializes recording and processing flags
    /// - Clears previous error messages
    /// - Resets transcription text buffer
    ///
    /// ## Usage Example
    /// ```swift
    /// let appState = AppState.shared
    /// appState.startTranscriptionSession()
    /// // Recording is now active, ready to receive audio
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1) - creates one session object
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: This method does not start actual audio capture. Use AudioManager to start recording.
    /// - SeeAlso: `stopTranscriptionSession()`, `TranscriptionSession`
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

    /// Stop the current transcription session and save final results.
    ///
    /// Finalizes the active transcription session by:
    /// - Recording end time and duration
    /// - Calculating final word count and confidence
    /// - Adding session to recent history (maintains last 50)
    /// - Resetting all recording state flags
    ///
    /// The completed session is automatically added to `recentSessions` for history
    /// tracking and export capabilities.
    ///
    /// ## Usage Example
    /// ```swift
    /// let appState = AppState.shared
    /// appState.stopTranscriptionSession()
    /// // Session is saved, recording flags cleared
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1) with O(n) for history trimming if > 50 sessions
    /// - Memory usage: O(1) - updates existing state
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: Does not stop actual audio capture. Use AudioManager.stopRecording()
    /// - SeeAlso: `startTranscriptionSession()`, `recentSessions`
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

    /// Update transcription text with new content from the recognition engine.
    ///
    /// Processes incoming transcription results and updates the session state.
    /// Handles both interim (partial) and final transcription results.
    ///
    /// When `isFinal` is true, the text is appended to the cumulative transcription
    /// with automatic spacing. Interim results are not added to the transcript.
    ///
    /// ## Usage Example
    /// ```swift
    /// // Update with final transcribed text
    /// appState.updateTranscription("Hello world", isFinal: true)
    ///
    /// // Update with interim (partial) results
    /// appState.updateTranscription("He...", isFinal: false)
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(n) where n is text length for word counting
    /// - Memory usage: O(1) - updates existing string
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameters:
    ///   - text: The transcribed text to add
    ///   - isFinal: Whether this is a final (vs interim) transcription result
    ///
    /// - Note: Only final text is permanently added to the transcript
    /// - SeeAlso: `clearTranscription()`, `currentSession`
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

    /// Clear current transcription text and error messages.
    ///
    /// Resets the transcription text buffer and clears any displayed errors.
    /// Does not affect the current session or recording state.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.clearTranscription()
    /// // Transcription text is now empty, ready for new content
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1) - deallocates string memory
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: This does not end the transcription session
    /// - SeeAlso: `updateTranscription(_:isFinal:)`, `stopTranscriptionSession()`
    public func clearTranscription() {
        transcriptionText = ""
        errorMessage = nil
        print("🎯 Transcription cleared")
    }

    /// Update connection status to transcription service.
    ///
    /// Updates the WebSocket connection state and automatically clears
    /// error messages when transitioning to connected state.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.setConnectionStatus(.connected)
    /// // UI will show green connected indicator
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter status: The new connection state
    /// - SeeAlso: `ConnectionStatus`, `connectionStatus`
    public func setConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status

        if status == .connected {
            errorMessage = nil
        }
    }

    /// Set error message to display to the user.
    ///
    /// Updates the current error message state. Pass nil to clear the error.
    /// Error messages are automatically logged to console for debugging.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.setError("Failed to connect to transcription service")
    /// // Error banner will appear in UI
    ///
    /// appState.setError(nil)
    /// // Error banner is cleared
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter message: The error message to display, or nil to clear
    /// - SeeAlso: `errorMessage`, `setConnectionStatus(_:)`
    public func setError(_ message: String?) {
        errorMessage = message
        if let errorMessage = message {
            print("🎯 Error set: \(errorMessage)")
        }
    }

    /// Update audio input level for visual feedback.
    ///
    /// Sets the current audio input level for visualization in the UI.
    /// Values are automatically clamped to the valid range [0.0, 1.0].
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.updateAudioLevel(0.75)
    /// // Audio level indicator shows 75% volume
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter level: Audio level between 0.0 (silent) and 1.0 (maximum)
    /// - Note: Called frequently during recording, should be lightweight
    /// - SeeAlso: `audioLevel`, `isRecording`
    public func updateAudioLevel(_ level: Float) {
        audioLevel = max(0.0, min(1.0, level))
    }

    /// Update performance metrics for monitoring and diagnostics.
    ///
    /// Records current transcription performance metrics including latency,
    /// confidence, and processing time. These metrics are used for performance
    /// monitoring and quality analysis.
    ///
    /// ## Usage Example
    /// ```swift
    /// let metrics = TranscriptionMetrics(
    ///     latency: 0.150,
    ///     confidence: 0.95,
    ///     wordCount: 42,
    ///     processingTime: 0.025
    /// )
    /// appState.updateMetrics(metrics)
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Parameter metrics: Current performance metrics snapshot
    /// - SeeAlso: `TranscriptionMetrics`, `currentMetrics`, `networkLatency`
    public func updateMetrics(_ metrics: TranscriptionMetrics) {
        currentMetrics = metrics
        networkLatency = metrics.latency
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

    /// Save current state to persistent storage.
    ///
    /// Persists user preferences including theme, language, and onboarding status
    /// to UserDefaults for retrieval across app launches.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.appTheme = .dark
    /// appState.saveState()
    /// // Theme preference is now persisted
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: Called automatically on important state changes
    /// - SeeAlso: `loadInitialState()`, `UserDefaults`
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
