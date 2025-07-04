import SwiftUI
import HotKey
import AppKit

/// Hotkey configuration view for customizing global shortcuts
@MainActor
public struct HotkeyConfigurationView: View {
    
    // MARK: - Properties
    
    @ObservedObject var hotkeyService: GlobalHotkeyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRecordingToggleHotkey = false
    @State private var isRecordingQuickHotkey = false
    @State private var toggleHotkeyDisplay = "⌘⌥Space"
    @State private var quickRecordHotkeyDisplay = "⌘⇧R"
    @State private var configurationMessage: String?
    
    // Current hotkey being recorded
    @State private var recordedKey: Key?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    
    // MARK: - Initialization
    
    public init(hotkeyService: GlobalHotkeyService) {
        self.hotkeyService = hotkeyService
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Configure Hotkeys")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Set custom keyboard shortcuts for floating microphone")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Hotkey Configuration Section
            VStack(spacing: 20) {
                // Toggle Widget Hotkey
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toggle Floating Widget")
                        .font(.headline)
                    
                    HStack {
                        HotkeyRecorderView(
                            isRecording: $isRecordingToggleHotkey,
                            displayText: $toggleHotkeyDisplay,
                            onHotkeyRecorded: { key, modifiers in
                                recordedKey = key
                                recordedModifiers = modifiers
                                updateToggleHotkey(key: key, modifiers: modifiers)
                            }
                        )
                        
                        Button("Reset to Default") {
                            resetToggleHotkey()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRecordingToggleHotkey || isRecordingQuickHotkey)
                    }
                    
                    Text("Shows/hides the floating microphone widget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Quick Record Hotkey
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Record")
                        .font(.headline)
                    
                    HStack {
                        HotkeyRecorderView(
                            isRecording: $isRecordingQuickHotkey,
                            displayText: $quickRecordHotkeyDisplay,
                            onHotkeyRecorded: { key, modifiers in
                                recordedKey = key
                                recordedModifiers = modifiers
                                updateQuickRecordHotkey(key: key, modifiers: modifiers)
                            }
                        )
                        
                        Button("Reset to Default") {
                            resetQuickRecordHotkey()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRecordingToggleHotkey || isRecordingQuickHotkey)
                    }
                    
                    Text("Shows widget and immediately starts recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Configuration Status
                if let message = configurationMessage {
                    HStack {
                        Image(systemName: message.contains("✓") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(message.contains("✓") ? .green : .orange)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("✓") ? .green : .orange)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Help Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Click on a hotkey field above")
                    Text("2. Press your desired key combination")
                    Text("3. The hotkey will be saved automatically")
                    Text("4. Use modifier keys like ⌘, ⌥, ⇧, ⌃ for better compatibility")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Test Current Hotkeys") {
                    testHotkeys()
                }
                .buttonStyle(.bordered)
                .disabled(isRecordingToggleHotkey || isRecordingQuickHotkey)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(width: 500, height: 650)
        .onAppear {
            loadCurrentHotkeys()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateToggleHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotkeyService.configureToggleHotkey(key: key, modifiers: modifiers)
        toggleHotkeyDisplay = formatHotkey(key: key, modifiers: modifiers)
        configurationMessage = "Toggle hotkey updated ✓"
        clearMessageAfterDelay()
    }
    
    private func updateQuickRecordHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotkeyService.configureQuickRecordHotkey(key: key, modifiers: modifiers)
        quickRecordHotkeyDisplay = formatHotkey(key: key, modifiers: modifiers)
        configurationMessage = "Quick record hotkey updated ✓"
        clearMessageAfterDelay()
    }
    
    private func resetToggleHotkey() {
        hotkeyService.configureToggleHotkey(key: .space, modifiers: [.command, .option])
        toggleHotkeyDisplay = "⌘⌥Space"
        configurationMessage = "Toggle hotkey reset to default ✓"
        clearMessageAfterDelay()
    }
    
    private func resetQuickRecordHotkey() {
        hotkeyService.configureQuickRecordHotkey(key: .r, modifiers: [.command, .shift])
        quickRecordHotkeyDisplay = "⌘⇧R"
        configurationMessage = "Quick record hotkey reset to default ✓"
        clearMessageAfterDelay()
    }
    
    private func testHotkeys() {
        configurationMessage = "Try using your configured hotkeys now!"
        clearMessageAfterDelay()
    }
    
    private func loadCurrentHotkeys() {
        let info = hotkeyService.getHotkeyInfo()
        toggleHotkeyDisplay = info["Toggle Widget"] ?? "⌘⌥Space"
        quickRecordHotkeyDisplay = info["Quick Record"] ?? "⌘⇧R"
    }
    
    private func formatHotkey(key: Key, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }
        
        parts.append(keyDisplayName(key))
        
        return parts.joined(separator: "")
    }
    
    private func keyDisplayName(_ key: Key) -> String {
        switch key {
        case .space: return "Space"
        case .r: return "R"
        case .return: return "Return"
        case .escape: return "Escape"
        case .delete: return "Delete"
        case .tab: return "Tab"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        default: return key.description
        }
    }
    
    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            configurationMessage = nil
        }
    }
}

/// Custom hotkey recorder view
struct HotkeyRecorderView: View {
    @Binding var isRecording: Bool
    @Binding var displayText: String
    let onHotkeyRecorded: (Key, NSEvent.ModifierFlags) -> Void
    
    @State private var localEventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                Text(isRecording ? "Press keys..." : displayText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isRecording ? .orange : .primary)
                
                Spacer()
                
                Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    .foregroundColor(isRecording ? .red : .secondary)
            }
            .padding()
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording ? Color.orange.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        print("🎬 Started recording hotkey...")
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
                print("🔍 Key pressed: keyCode=\(event.keyCode), modifiers=\(modifiers)")
                
                // Only process if we have modifiers (prevent recording single letters)
                if !modifiers.isEmpty {
                    // Convert NSEvent key to HotKey.Key
                    if let key = keyFromKeyCode(event.keyCode) {
                        print("✅ Valid hotkey recorded: \(modifiers) + \(key)")
                        DispatchQueue.main.async {
                            self.stopRecording()
                            self.onHotkeyRecorded(key, modifiers)
                        }
                        return nil // Consume the event
                    } else {
                        print("❌ Unknown keyCode: \(event.keyCode)")
                    }
                } else {
                    print("⚠️ No modifiers detected, ignoring")
                }
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func keyFromKeyCode(_ keyCode: UInt16) -> Key? {
        // Map key codes to HotKey.Key values
        switch keyCode {
        // Special keys
        case 49: return .space
        case 36: return .return
        case 53: return .escape
        case 51: return .delete
        case 48: return .tab
        
        // Function keys
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        
        // Numbers
        case 29: return .zero
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 23: return .five
        case 22: return .six
        case 26: return .seven
        case 28: return .eight
        case 25: return .nine
        
        // Letters
        case 0: return .a
        case 11: return .b
        case 8: return .c
        case 2: return .d
        case 14: return .e
        case 3: return .f
        case 5: return .g
        case 4: return .h
        case 34: return .i
        case 38: return .j
        case 40: return .k
        case 37: return .l
        case 46: return .m
        case 45: return .n
        case 31: return .o
        case 35: return .p
        case 12: return .q
        case 15: return .r
        case 1: return .s
        case 17: return .t
        case 32: return .u
        case 9: return .v
        case 13: return .w
        case 7: return .x
        case 16: return .y
        case 6: return .z
        
        // Arrow keys
        case 123: return .leftArrow
        case 124: return .rightArrow
        case 125: return .downArrow
        case 126: return .upArrow
        
        default: return nil
        }
    }
}

// MARK: - Preview

#Preview {
    HotkeyConfigurationView(hotkeyService: GlobalHotkeyService())
}