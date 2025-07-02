import Foundation
import SwiftUI

// MARK: - Example App Integration

/// Example of how to integrate DI into a SwiftUI app
struct VoiceFlowApp: App {
    
    init() {
        // Bootstrap the DI container on app launch
        setupDependencyInjection()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppViewModel())
        }
    }
    
    private func setupDependencyInjection() {
        // Bootstrap with default configuration
        DIBootstrap().bootstrap()
        
        // Or use custom configuration
        // let config = AppConfiguration(
        //     enableUI: true,
        //     enableTranscription: true,
        //     enableExport: true,
        //     enableDeveloperMode: false
        // )
        // DIBootstrap().bootstrapWithConfiguration(config)
    }
}

// MARK: - Example View Model

/// Example view model using dependency injection
@MainActor
class AppViewModel: ObservableObject {
    
    // Using property wrapper for automatic injection
    @Injected private var settings: SettingsServiceProtocol
    @Injected private var sessionStorage: SessionStorageServiceProtocol
    @Injected private var hotkeys: HotkeyServiceProtocol
    
    // Published properties for UI binding
    @Published var isRecording = false
    @Published var sessions: [StoredTranscriptionSession] = []
    
    init() {
        // Load initial data
        Task {
            await loadSessions()
        }
        
        // Setup hotkey callbacks
        setupHotkeys()
    }
    
    // MARK: - Public Methods
    
    func toggleRecording() {
        isRecording.toggle()
        // Handle recording logic
    }
    
    func loadSessions() async {
        await sessionStorage.loadSessions()
        sessions = sessionStorage.sessions
    }
    
    func updateLanguage(_ language: String) {
        settings.selectedLanguage = language
    }
    
    // MARK: - Private Methods
    
    private func setupHotkeys() {
        hotkeys.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
    }
}

// MARK: - Example View

/// Example SwiftUI view using the view model
struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        VStack {
            Text("VoiceFlow")
                .font(.largeTitle)
            
            Button(action: viewModel.toggleRecording) {
                Label(
                    viewModel.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: viewModel.isRecording ? "stop.circle" : "record.circle"
                )
            }
            .keyboardShortcut(.space, modifiers: [.command, .option])
            
            List(viewModel.sessions) { session in
                SessionRow(session: session)
            }
        }
        .padding()
    }
}

struct SessionRow: View {
    let session: StoredTranscriptionSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.preview)
                .lineLimit(2)
            Text(session.formattedStartTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Example Service Usage

/// Example of directly using services without property wrapper
class TranscriptionController {
    private let container = DIContainer.shared
    
    func startTranscription() async throws {
        // Resolve services when needed
        let settings = try container.resolve(SettingsServiceProtocol.self)
        let sessionStorage = try container.resolve(SessionStorageServiceProtocol.self)
        
        // Use the services
        let language = settings.selectedLanguage
        // ... transcription logic using the language setting
        
        // Save session when done
        // await sessionStorage.saveSession(transcriptionSession)
    }
}

// MARK: - Example Testing

/// Example of testing with mock services
class MockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var launchAtLogin = false
    @Published var showFloatingWidget = true
    @Published var floatingWidgetAlwaysOnTop = true
    @Published var menuBarIcon = MenuBarIconStyle.colored
    @Published var selectedLanguage = "en-US"
    @Published var enablePunctuation = true
    @Published var enableCapitalization = true
    @Published var confidenceThreshold = 0.7
    @Published var enableContextAwareCorrections = true
    @Published var enableRealTimeTranscription = true
    @Published var autoSaveSessions = true
    @Published var privacyMode = PrivacyMode.balanced
    @Published var dataRetentionDays = 30
    @Published var enableAnalytics = false
    @Published var enableCrashReporting = true
    @Published var customVocabulary: [String] = []
    @Published var preferOnDeviceRecognition = true
    @Published var enableDeveloperMode = false
    @Published var logLevel = LogLevel.info
    @Published var maxBufferSize = 1024
    
    func resetToDefaults() {}
    func exportSettings() throws -> Data { Data() }
    func importSettings(from data: Data) throws {}
    func addCustomVocabularyWord(_ word: String) {}
    func removeCustomVocabularyWord(_ word: String) {}
    func getAvailableLanguages() -> [VoiceLanguage] { [] }
}

// In your tests:
func setupTestEnvironment() {
    DIContainer.shared.reset()
    DIContainer.shared.register(MockSettingsService(), for: SettingsServiceProtocol.self)
}