import Foundation

/// Service container for dependency injection following SOLID principles
/// Provides centralized configuration of all services with proper lifecycle management
@MainActor
public final class ServiceContainer {
    
    // MARK: - Shared Instance
    
    public static let shared = ServiceContainer()
    
    // MARK: - Service Instances
    
    // Core Services
    private lazy var _languageService = LanguageService()
    private lazy var _settingsService = SettingsService()
    
    // Domain Services
    private lazy var _sessionManager = SessionManager(storage: UserDefaultsSessionStorage())
    private lazy var _exportService = TranscriptionExportService()
    
    // Transcription Engine Components (following composition pattern)
    private lazy var _contextProcessor = ContextProcessor()
    private lazy var _speechRecognitionManager = SpeechRecognitionManager()
    private lazy var _audioProcessor = AudioProcessor()
    private lazy var _errorHandler = SpeechErrorHandler()
    private lazy var _transcriptionProcessor = TranscriptionProcessor(contextProcessor: _contextProcessor)
    
    // Composed Transcription Engine
    private lazy var _transcriptionEngine = RefactoredRealSpeechRecognitionEngine()
    
    // ViewModels
    private lazy var _transcriptionViewModel = RefactoredTranscriptionViewModel(
        transcriptionEngine: _transcriptionEngine,
        sessionManager: _sessionManager,
        exportService: _exportService
    )
    
    // MARK: - Initialization
    
    private init() {
        setupServiceBindings()
    }
    
    // MARK: - Service Access (Factory Methods)
    
    public func languageService() -> LanguageService {
        return _languageService
    }
    
    public func settingsService() -> SettingsService {
        return _settingsService
    }
    
    public func sessionManager() -> SessionManager {
        return _sessionManager
    }
    
    public func exportService() -> TranscriptionExportService {
        return _exportService
    }
    
    public func transcriptionEngine() -> TranscriptionEngineProtocol {
        return _transcriptionEngine
    }
    
    public func transcriptionViewModel() -> RefactoredTranscriptionViewModel {
        return _transcriptionViewModel
    }
    
    // Component-level access for testing and advanced usage
    public func contextProcessor() -> ContextProcessor {
        return _contextProcessor
    }
    
    public func speechRecognitionManager() -> SpeechRecognitionManager {
        return _speechRecognitionManager
    }
    
    public func audioProcessor() -> AudioProcessor {
        return _audioProcessor
    }
    
    public func errorHandler() -> SpeechErrorHandler {
        return _errorHandler
    }
    
    public func transcriptionProcessor() -> TranscriptionProcessor {
        return _transcriptionProcessor
    }
    
    // MARK: - Service Configuration
    
    private func setupServiceBindings() {
        // Setup cross-service communication
        setupLanguageServiceBindings()
        setupSettingsServiceBindings()
    }
    
    private func setupLanguageServiceBindings() {
        // Listen for language changes and update transcription engine
        NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let languageCode = notification.object as? String else { return }
            
            Task { @MainActor in
                await self?._transcriptionEngine.setLanguage(languageCode)
            }
        }
    }
    
    private func setupSettingsServiceBindings() {
        // Could setup bindings for settings changes affecting transcription
        // For example, updating confidence thresholds, vocabulary, etc.
    }
    
    // MARK: - Service Lifecycle
    
    public func configureServices() async {
        // Perform any async setup required by services
        // This method should be called during app startup
        
        // Example: Pre-load language data, initialize audio system, etc.
        let _ = _languageService.getAvailableLanguages()
        
        // Setup initial context based on current settings
        await _transcriptionEngine.setContext(.general)
    }
    
    public func shutdownServices() async {
        // Cleanup services gracefully
        if _transcriptionViewModel.isTranscribing {
            await _transcriptionViewModel.stopTranscription()
        }
    }
}

// MARK: - Convenience Extensions for SwiftUI

extension ServiceContainer {
    
    /// Creates a new view model instance with fresh state but shared services
    /// Useful for SwiftUI previews or testing
    public func createTranscriptionViewModel() -> RefactoredTranscriptionViewModel {
        return RefactoredTranscriptionViewModel(
            transcriptionEngine: transcriptionEngine(),
            sessionManager: sessionManager(),
            exportService: exportService()
        )
    }
}

// MARK: - Protocol for Testing

public protocol ServiceContainerProtocol {
    func languageService() -> LanguageService
    func settingsService() -> SettingsService
    func sessionManager() -> SessionManager
    func exportService() -> TranscriptionExportService
    func transcriptionEngine() -> TranscriptionEngineProtocol
    func transcriptionViewModel() -> RefactoredTranscriptionViewModel
}

extension ServiceContainer: ServiceContainerProtocol {}

// MARK: - Mock Service Container for Testing

#if DEBUG
public final class MockServiceContainer: ServiceContainerProtocol {
    
    public init() {}
    
    public func languageService() -> LanguageService {
        return LanguageService()
    }
    
    public func settingsService() -> SettingsService {
        return SettingsService()
    }
    
    public func sessionManager() -> SessionManager {
        return SessionManager(storage: MockSessionStorage())
    }
    
    public func exportService() -> TranscriptionExportService {
        return TranscriptionExportService()
    }
    
    public func transcriptionEngine() -> TranscriptionEngineProtocol {
        return MockTranscriptionEngine()
    }
    
    public func transcriptionViewModel() -> RefactoredTranscriptionViewModel {
        return RefactoredTranscriptionViewModel(
            transcriptionEngine: transcriptionEngine(),
            sessionManager: sessionManager(),
            exportService: exportService()
        )
    }
}

// Mock implementations for testing
private class MockSessionStorage: SessionStorageProtocol {
    private var sessions: [TranscriptionSession] = []
    
    func saveSession(_ session: TranscriptionSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }
    
    func loadAllSessions() async throws -> [TranscriptionSession] {
        return sessions
    }
    
    func deleteSession(_ sessionId: UUID) async throws {
        sessions.removeAll { $0.id == sessionId }
    }
    
    func clearAllSessions() async throws {
        sessions.removeAll()
    }
}

private class MockTranscriptionEngine: TranscriptionEngineProtocol {
    var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> {
        Just(TranscriptionUpdate(type: .partial, text: "Mock transcription", confidence: 0.8))
            .eraseToAnyPublisher()
    }
    
    func startTranscription() async throws {}
    func stopTranscription() async {}
    func pauseTranscription() async {}
    func resumeTranscription() async {}
    func setLanguage(_ language: String) async {}
    func setContext(_ context: AppContext) async {}
    func addCustomVocabulary(_ words: [String]) async {}
}

#endif