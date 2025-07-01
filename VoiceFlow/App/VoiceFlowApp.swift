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
    private var transcriptionViewModel: TranscriptionViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize view model
        transcriptionViewModel = TranscriptionViewModel()
        
        // Initialize menu bar with view model
        if let viewModel = transcriptionViewModel {
            menuBarController = MenuBarController(viewModel: viewModel)
        }
        
        // Initialize floating widget with view model
        if let viewModel = transcriptionViewModel {
            floatingWidgetController = FloatingWidgetController(viewModel: viewModel)
        }
        
        // Hide main window initially
        NSApp.windows.forEach { $0.orderOut(nil) }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        Task {
            await transcriptionViewModel?.stopTranscription()
        }
    }
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


extension NSAlert {
    static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }
}