import SwiftUI

public struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showFloatingWidget") private var showFloatingWidget = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "en-US"
    @AppStorage("accuracyMode") private var accuracyMode = "balanced"
    @AppStorage("privacyMode") private var privacyMode = "balanced"
    @AppStorage("retainTranscriptions") private var retainTranscriptions = true
    @AppStorage("retentionDays") private var retentionDays = 30
    @AppStorage("enableAnalytics") private var enableAnalytics = false
    
    @State private var customVocabulary = ""
    @State private var selectedTab = "general"
    
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
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // TODO: Implement launch at login
                    }
                
                // Show floating widget
                Toggle("Show Floating Widget", isOn: $showFloatingWidget)
                
                // Global hotkey
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Hotkey")
                        .font(.headline)
                    HStack {
                        Text("⌘⌥Space")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.quaternary)
                            .cornerRadius(6)
                        
                        Button("Change") {
                            // TODO: Implement hotkey recording
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Press this combination anywhere to start/stop transcription")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    Picker("", selection: $transcriptionLanguage) {
                        Text("Automatic").tag("auto")
                        Divider()
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("Spanish").tag("es-ES")
                        Text("French").tag("fr-FR")
                        Text("German").tag("de-DE")
                        Text("Chinese").tag("zh-CN")
                        Text("Japanese").tag("ja-JP")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                // Accuracy mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accuracy Mode")
                        .font(.headline)
                    Picker("", selection: $accuracyMode) {
                        VStack(alignment: .leading) {
                            Text("Fast")
                            Text("Lower accuracy, minimal latency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("fast")
                        
                        VStack(alignment: .leading) {
                            Text("Balanced")
                            Text("Good accuracy, low latency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("balanced")
                        
                        VStack(alignment: .leading) {
                            Text("Accurate")
                            Text("Best accuracy, higher latency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("accurate")
                    }
                    .pickerStyle(.radioGroup)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.headline)
                    Toggle("Auto-punctuation", isOn: .constant(true))
                    Toggle("Auto-capitalization", isOn: .constant(true))
                    Toggle("Smart formatting", isOn: .constant(true))
                    Toggle("Context awareness", isOn: .constant(true))
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
                    Picker("", selection: $privacyMode) {
                        VStack(alignment: .leading) {
                            Text("Maximum")
                            Text("No data leaves your device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("maximum")
                        
                        VStack(alignment: .leading) {
                            Text("Balanced")
                            Text("Anonymous usage data only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("balanced")
                        
                        VStack(alignment: .leading) {
                            Text("Convenience")
                            Text("Full features with encryption")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag("convenience")
                    }
                    .pickerStyle(.radioGroup)
                }
                
                Divider()
                
                // Data retention
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Retain Transcriptions", isOn: $retainTranscriptions)
                    
                    if retainTranscriptions {
                        HStack {
                            Text("Delete after")
                            Picker("", selection: $retentionDays) {
                                Text("7 days").tag(7)
                                Text("30 days").tag(30)
                                Text("90 days").tag(90)
                                Text("Never").tag(0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        .padding(.leading, 20)
                    }
                }
                
                // Analytics
                Toggle("Share Anonymous Usage Data", isOn: $enableAnalytics)
                    .disabled(privacyMode == "maximum")
                
                // Clear data
                Button("Clear All Transcription Data...") {
                    // TODO: Implement data clearing
                }
                .foregroundColor(.red)
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
                    
                    TextEditor(text: $customVocabulary)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("One term per line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Model selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speech Model")
                        .font(.headline)
                    Picker("", selection: .constant("enhanced")) {
                        Text("Compact (50MB)").tag("compact")
                        Text("Enhanced (250MB)").tag("enhanced")
                        Text("Professional (500MB)").tag("professional")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                // Developer options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer Options")
                        .font(.headline)
                    Toggle("Show debug information", isOn: .constant(false))
                    Toggle("Enable verbose logging", isOn: .constant(false))
                    Button("Export Logs...") {
                        // TODO: Implement log export
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