import SwiftUI

public struct SettingsView: View {
    @StateObject private var settingsService = SettingsService()
    @StateObject private var hotkeyService = HotkeyService()
    
    @State private var newVocabularyWord = ""
    @State private var selectedTab = "general"
    @State private var showingHotkeyRecorder = false
    @State private var recordingHotkeyFor: HotkeyAction?
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Sidebar
            sidebar
                .frame(width: 150)
                .frame(minWidth: 150, maxWidth: 200)
            
            // Content
            TabView(selection: $selectedTab) {
                generalSettings
                    .tag("general")
                    .tabItem { EmptyView() }
                
                transcriptionSettings
                    .tag("transcription")
                    .tabItem { EmptyView() }
                
                privacySettings
                    .tag("privacy")
                    .tabItem { EmptyView() }
                
                advancedSettings
                    .tag("advanced")
                    .tabItem { EmptyView() }
                
                aboutView
                    .tag("about")
                    .tabItem { EmptyView() }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .background(WindowBackground())
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsSidebarItem(
                icon: "gear",
                title: "General",
                isSelected: selectedTab == "general"
            ) {
                selectedTab = "general"
            }
            
            SettingsSidebarItem(
                icon: "mic",
                title: "Transcription",
                isSelected: selectedTab == "transcription"
            ) {
                selectedTab = "transcription"
            }
            
            SettingsSidebarItem(
                icon: "lock",
                title: "Privacy",
                isSelected: selectedTab == "privacy"
            ) {
                selectedTab = "privacy"
            }
            
            SettingsSidebarItem(
                icon: "gearshape.2",
                title: "Advanced",
                isSelected: selectedTab == "advanced"
            ) {
                selectedTab = "advanced"
            }
            
            Spacer()
            
            SettingsSidebarItem(
                icon: "info.circle",
                title: "About",
                isSelected: selectedTab == "about"
            ) {
                selectedTab = "about"
            }
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Launch at login
                Toggle("Launch at Login", isOn: $settingsService.launchAtLogin)
                
                // Show floating widget
                Toggle("Show Floating Widget", isOn: $settingsService.showFloatingWidget)
                
                // Floating widget settings
                if settingsService.showFloatingWidget {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Always on Top", isOn: $settingsService.floatingWidgetAlwaysOnTop)
                            .padding(.leading, 20)
                    }
                }
                
                // Menu bar icon
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu Bar Icon")
                        .font(.headline)
                    Picker("Icon Style", selection: $settingsService.menuBarIcon) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Global hotkeys
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Hotkeys")
                        .font(.headline)
                    
                    ForEach(HotkeyAction.allCases, id: \.self) { action in
                        HStack {
                            Text(action.rawValue)
                                .frame(width: 140, alignment: .leading)
                            
                            let hotkey = getHotkey(for: action)
                            Text(hotkeyDisplayString(for: hotkey))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary)
                                .cornerRadius(6)
                                .monospaced()
                            
                            Button("Change") {
                                recordingHotkeyFor = action
                                showingHotkeyRecorder = true
                            }
                            
                            Button("Clear") {
                                hotkeyService.clearHotkey(for: action)
                            }
                        }
                        .buttonStyle(.plain)
                    }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Transcription Settings
    
    private var transcriptionSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Transcription")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Language selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Language")
                        .font(.headline)
                    Picker("", selection: $settingsService.selectedLanguage) {
                        ForEach(settingsService.getAvailableLanguages()) { language in
                            Text(language.displayName).tag(language.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 250)
                }
                
                // Transcription features
                Toggle("Enable Punctuation", isOn: $settingsService.enablePunctuation)
                Toggle("Enable Capitalization", isOn: $settingsService.enableCapitalization)
                Toggle("Context-Aware Corrections", isOn: $settingsService.enableContextAwareCorrections)
                Toggle("Real-Time Transcription", isOn: $settingsService.enableRealTimeTranscription)
                Toggle("Auto-Save Sessions", isOn: $settingsService.autoSaveSessions)
                
                // Confidence threshold
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence Threshold: \(Int(settingsService.confidenceThreshold * 100))%")
                        .font(.headline)
                    Slider(value: $settingsService.confidenceThreshold, in: 0.3...1.0, step: 0.05)
                    Text("Lower values may include less accurate transcriptions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
            }
            
            Spacer()
        }
    }
    
    // MARK: - Privacy Settings
    
    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Privacy")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Privacy mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Mode")
                        .font(.headline)
                    Picker("", selection: $settingsService.privacyMode) {
                        ForEach(PrivacyMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }.tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                
                Divider()
                
                // Data retention
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Retention")
                        .font(.headline)
                    HStack {
                        Text("Delete transcriptions after")
                        Picker("", selection: $settingsService.dataRetentionDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("1 year").tag(365)
                            Text("Never").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                
                Divider()
                
                // Analytics and telemetry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analytics & Diagnostics")
                        .font(.headline)
                    Toggle("Share Anonymous Usage Data", isOn: $settingsService.enableAnalytics)
                    Toggle("Share Crash Reports", isOn: $settingsService.enableCrashReporting)
                }
                
                Divider()
                
                // Danger zone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundColor(.red)
                    Button("Clear All Transcription Data...") {
                        // TODO: Implement data clearing confirmation dialog
                    }
                    .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Custom vocabulary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Vocabulary")
                        .font(.headline)
                    Text("Add technical terms, names, or jargon for better recognition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Vocabulary list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(settingsService.customVocabulary, id: \.self) { word in
                                HStack {
                                    Text(word)
                                    Spacer()
                                    Button("Remove") {
                                        settingsService.removeCustomVocabularyWord(word)
                                    }
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Add new word
                    HStack {
                        TextField("Add word...", text: $newVocabularyWord)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            settingsService.addCustomVocabularyWord(newVocabularyWord)
                            newVocabularyWord = ""
                        }
                        .disabled(newVocabularyWord.isEmpty)
                    }
                }
                
                // Recognition preferences
                Toggle("Prefer On-Device Recognition", isOn: $settingsService.preferOnDeviceRecognition)
                
                // Buffer size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Buffer Size: \(settingsService.maxBufferSize)")
                        .font(.headline)
                    Slider(value: Binding(
                        get: { Double(settingsService.maxBufferSize) },
                        set: { settingsService.maxBufferSize = Int($0) }
                    ), in: 256...4096, step: 256)
                    Text("Higher values may improve accuracy but increase latency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Developer options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer Options")
                        .font(.headline)
                    Toggle("Enable Developer Mode", isOn: $settingsService.enableDeveloperMode)
                    
                    if settingsService.enableDeveloperMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Log Level", selection: $settingsService.logLevel) {
                                ForEach(LogLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                            
                            HStack {
                                Button("Export Settings...") {
                                    exportSettings()
                                }
                                Button("Import Settings...") {
                                    importSettings()
                                }
                                Button("Reset to Defaults") {
                                    settingsService.resetToDefaults()
                                }
                                .foregroundColor(.orange)
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            // App icon and name
            VStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("VoiceFlow")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("High-performance voice transcription for macOS")
                .font(.body)
                .multilineTextAlignment(.center)
            
            // Links
            VStack(spacing: 8) {
                Link("Visit Website", destination: URL(string: "https://voiceflow.app")!)
                Link("View on GitHub", destination: URL(string: "https://github.com/voiceflow")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/voiceflow/issues")!)
            }
            .font(.caption)
            
            Divider()
                .frame(width: 200)
            
            // Credits
            VStack(spacing: 4) {
                Text("Created with ❤️ for the macOS community")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("© 2025 VoiceFlow. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            
            // Acknowledgments
            Button("Acknowledgments") {
                // TODO: Show acknowledgments window
            }
            .buttonStyle(.link)
            .font(.caption)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func getHotkey(for action: HotkeyAction) -> HotKey? {
        switch action {
        case .toggleRecording:
            return hotkeyService.toggleRecordingHotkey
        case .showFloatingWidget:
            return hotkeyService.showFloatingWidgetHotkey
        case .showMainWindow:
            return hotkeyService.showMainWindowHotkey
        }
    }
    
    private func hotkeyDisplayString(for hotkey: HotKey?) -> String {
        guard let hotkey = hotkey else { return "None" }
        let modifiers = hotkey.modifiers.displayString
        let key = hotkey.key.displayName
        return modifiers + key
    }
    
    private func exportSettings() {
        let panel = NSSavePanel()
        panel.title = "Export Settings"
        panel.nameFieldStringValue = "VoiceFlow-Settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try settingsService.exportSettings()
                    try data.write(to: url)
                } catch {
                    print("Failed to export settings: \(error)")
                }
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                do {
                    let data = try Data(contentsOf: url)
                    try settingsService.importSettings(from: data)
                } catch {
                    print("Failed to import settings: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SettingsSidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct WindowBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor))
            .overlay(
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                    .opacity(0.5)
            )
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}