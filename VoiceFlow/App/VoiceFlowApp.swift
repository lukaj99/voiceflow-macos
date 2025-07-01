import SwiftUI
import AppKit

@main
struct VoiceFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var transcriptionViewModel = TranscriptionViewModel()
    
    var body: some Scene {
        // Main window group (hidden by default)
        WindowGroup("VoiceFlow") {
            TranscriptionMainView(viewModel: transcriptionViewModel)
                .frame(
                    minWidth: 400, minHeight: 300,
                    idealWidth: 600, idealHeight: 400,
                    maxWidth: 1200, maxHeight: 800
                )
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var floatingWidgetController: FloatingWidgetController?
    private var transcriptionEngine: SpeechAnalyzerEngine?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar
        menuBarController = MenuBarController()
        
        // Initialize floating widget
        floatingWidgetController = FloatingWidgetController()
        
        // Initialize transcription engine
        Task {
            await initializeTranscriptionEngine()
        }
        
        // Hide main window initially
        NSApp.windows.forEach { $0.orderOut(nil) }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        Task {
            await transcriptionEngine?.stopTranscription()
        }
    }
    
    private func initializeTranscriptionEngine() async {
        do {
            transcriptionEngine = SpeechAnalyzerEngine()
            // Engine will be connected to UI via Combine publishers
        } catch {
            NSAlert.showError(error)
        }
    }
}

// Placeholder view models and views (to be implemented)
class TranscriptionViewModel: ObservableObject {
    @Published var transcribedText = ""
    @Published var isTranscribing = false
    @Published var currentAudioLevel: Float = 0
}

struct TranscriptionMainView: View {
    @StateObject var viewModel: TranscriptionViewModel
    
    var body: some View {
        Text("Transcription View - To be implemented")
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings - To be implemented")
            .frame(width: 500, height: 400)
    }
}

// Placeholder controllers (to be implemented)
class MenuBarController {
    init() {}
}

class FloatingWidgetController {
    init() {}
}

class SpeechAnalyzerEngine {
    func stopTranscription() async {}
}

extension NSAlert {
    static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }
}