import Foundation
import HotKey
import AppKit

/// Service for managing global hotkeys
/// Handles keyboard shortcuts for activating floating microphone widget
@MainActor
public class GlobalHotkeyService: ObservableObject {

    // MARK: - Published Properties

    @Published public var isEnabled = true
    @Published public var hotkeyStatus = "Ready"

    // MARK: - Private Properties

    private var toggleWidgetHotkey: HotKey?
    private var quickRecordHotkey: HotKey?

    // Default hotkey combinations
    private let defaultToggleKey: Key = .space
    private let defaultToggleModifiers: NSEvent.ModifierFlags = [.command, .option]

    private let defaultQuickRecordKey: Key = .r
    private let defaultQuickRecordModifiers: NSEvent.ModifierFlags = [.command, .shift]

    // Dependencies
    private weak var floatingWidget: FloatingMicrophoneWidget?

    // MARK: - Initialization

    public init() {
        setupDefaultHotkeys()
        print("⌨️ GlobalHotkeyService initialized")
    }

    // MARK: - Public Methods

    /// Set the floating widget to control
    public func setFloatingWidget(_ widget: FloatingMicrophoneWidget) {
        self.floatingWidget = widget
        print("⌨️ Floating widget connected to hotkey service")
    }

    /// Enable global hotkeys
    public func enable() {
        guard !isEnabled else { return }

        isEnabled = true
        setupDefaultHotkeys()
        hotkeyStatus = "Enabled"

        print("⌨️ Global hotkeys enabled")
    }

    /// Disable global hotkeys
    public func disable() {
        guard isEnabled else { return }

        isEnabled = false
        removeAllHotkeys()
        hotkeyStatus = "Disabled"

        print("⌨️ Global hotkeys disabled")
    }

    /// Toggle hotkey service
    public func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// Configure custom hotkey for toggle widget
    public func configureToggleHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        removeToggleHotkey()

        toggleWidgetHotkey = HotKey(key: key, modifiers: modifiers)
        toggleWidgetHotkey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleToggleWidget()
            }
        }

        hotkeyStatus = "Custom hotkey configured"
        print("⌨️ Toggle hotkey configured: \(modifiersString(modifiers)) + \(key)")
    }

    /// Configure custom hotkey for quick record
    public func configureQuickRecordHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        removeQuickRecordHotkey()

        quickRecordHotkey = HotKey(key: key, modifiers: modifiers)
        quickRecordHotkey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleQuickRecord()
            }
        }

        print("⌨️ Quick record hotkey configured: \(modifiersString(modifiers)) + \(key)")
    }

    /// Get current hotkey configuration info
    public func getHotkeyInfo() -> [String: String] {
        var info: [String: String] = [:]

        // Show actual configured hotkeys or defaults
        if let _ = toggleWidgetHotkey {
            info["Toggle Widget"] = "\(modifiersString(defaultToggleModifiers))\(keyDisplayName(defaultToggleKey))"
        } else {
            info["Toggle Widget"] = "Not configured"
        }

        if let _ = quickRecordHotkey {
            info["Quick Record"] = "\(modifiersString(defaultQuickRecordModifiers))\(keyDisplayName(defaultQuickRecordKey))"
        } else {
            info["Quick Record"] = "Not configured"
        }

        info["Status"] = hotkeyStatus
        info["Enabled"] = isEnabled ? "Yes" : "No"

        return info
    }

    // MARK: - Helper Methods

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

    // MARK: - Private Methods

    private func setupDefaultHotkeys() {
        removeAllHotkeys()

        guard isEnabled else { return }

        // Setup toggle widget hotkey (Cmd+Option+Space)
        toggleWidgetHotkey = HotKey(key: defaultToggleKey, modifiers: defaultToggleModifiers)
        toggleWidgetHotkey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleToggleWidget()
            }
        }

        print("⌨️ Toggle widget hotkey registered: ⌘⌥Space")

        // Setup quick record hotkey (Cmd+Shift+R)
        quickRecordHotkey = HotKey(key: defaultQuickRecordKey, modifiers: defaultQuickRecordModifiers)
        quickRecordHotkey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleQuickRecord()
            }
        }

        print("⌨️ Quick record hotkey registered: ⌘⇧R")

        hotkeyStatus = "Default hotkeys active"
    }

    private func removeAllHotkeys() {
        removeToggleHotkey()
        removeQuickRecordHotkey()
    }

    private func removeToggleHotkey() {
        toggleWidgetHotkey = nil
    }

    private func removeQuickRecordHotkey() {
        quickRecordHotkey = nil
    }

    // MARK: - Hotkey Handlers

    private func handleToggleWidget() {
        guard let widget = floatingWidget else {
            print("⌨️ Toggle widget hotkey pressed but no widget available")
            return
        }

        print("⌨️ Toggle widget hotkey activated")
        widget.toggle()
    }

    private func handleQuickRecord() {
        guard let widget = floatingWidget else {
            print("⌨️ Quick record hotkey pressed but no widget available")
            return
        }

        print("⌨️ Quick record hotkey activated")

        if widget.isVisible {
            // If widget is visible, toggle recording
            widget.toggleRecording()
        } else {
            // If widget is hidden, show and start recording
            widget.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                widget.startRecording()
            }
        }
    }

    private func modifiersString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }

        return parts.joined(separator: "")
    }
}

// Note: Key already conforms to CustomStringConvertible in HotKey framework
