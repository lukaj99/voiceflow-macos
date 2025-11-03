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

    func testHotkeys() {
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

    // Static constant for O(1) lookup without repeated allocation
    private static let displayNames: [Key: String] = [
        .space: "Space", .r: "R", .return: "Return", .escape: "Escape",
        .delete: "Delete", .tab: "Tab", .f1: "F1", .f2: "F2",
        .f3: "F3", .f4: "F4", .f5: "F5", .f6: "F6",
        .f7: "F7", .f8: "F8", .f9: "F9", .f10: "F10",
        .f11: "F11", .f12: "F12"
    ]

    private func keyDisplayName(_ key: Key) -> String {
        return Self.displayNames[key] ?? key.description
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

    // Static constant for O(1) lookup without repeated allocation
    private static let keyCodeMapping: [UInt16: Key] = [
        // Special keys
        49: .space, 36: .return, 53: .escape, 51: .delete, 48: .tab,
        // Function keys
        122: .f1, 120: .f2, 99: .f3, 118: .f4, 96: .f5, 97: .f6,
        98: .f7, 100: .f8, 101: .f9, 109: .f10, 103: .f11, 111: .f12,
        // Numbers
        29: .zero, 18: .one, 19: .two, 20: .three, 21: .four,
        23: .five, 22: .six, 26: .seven, 28: .eight, 25: .nine,
        // Letters
        0: .a, 11: .b, 8: .c, 2: .d, 14: .e, 3: .f, 5: .g, 4: .h,
        34: .i, 38: .j, 40: .k, 37: .l, 46: .m, 45: .n, 31: .o, 35: .p,
        12: .q, 15: .r, 1: .s, 17: .t, 32: .u, 9: .v, 13: .w, 7: .x,
        16: .y, 6: .z,
        // Arrow keys
        123: .leftArrow, 124: .rightArrow, 125: .downArrow, 126: .upArrow
    ]

    private func keyFromKeyCode(_ keyCode: UInt16) -> Key? {
        return Self.keyCodeMapping[keyCode]
    }
}

// MARK: - Preview

#Preview {
    HotkeyConfigurationView(hotkeyService: GlobalHotkeyService())
}
