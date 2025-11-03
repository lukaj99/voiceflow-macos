import SwiftUI

/// Modern VoiceFlow macOS App
/// Built with Swift 6 following 2025 security and architecture best practices
@main
struct VoiceFlowApp: App {

    // Shared app state with floating widget support
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("VoiceFlow") {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .onAppear {
                    setupApp()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(appState: appState)
        }

        // Settings window
        Settings {
            SettingsView(viewModel: SimpleTranscriptionViewModel())
                .frame(width: 500, height: 600)
        }
    }

    /// Configure app on startup
    private func setupApp() {
        print("🚀 VoiceFlow starting up...")
        print("🔐 Secure credentials: Keychain-based storage")
        print("🎯 Architecture: Swift 6 with actor isolation")
        print("🛡️ Security: App Sandbox enabled")
        print("🎨 UI: Modern SwiftUI with @Observable patterns")
    }
}

/// Native macOS menu commands
struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check Health Status") {
                print("🩺 Performing health check...")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Divider()

            Button("Show Floating Microphone") {
                appState.showFloatingWidget()
            }
            .keyboardShortcut(" ", modifiers: [.command, .option])

            Button("Toggle Global Hotkeys") {
                if appState.isGlobalHotkeysEnabled {
                    appState.disableGlobalHotkeys()
                } else {
                    appState.enableGlobalHotkeys()
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button("VoiceFlow Help") {
                print("📚 Opening help...")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
