import Foundation
import Carbon
import HotKey
import AppKit

/// Service for managing global hotkeys
@MainActor
public final class HotkeyService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var toggleRecordingHotkey: HotKey? {
        didSet {
            saveHotkey("ToggleRecording", hotkey: toggleRecordingHotkey)
        }
    }
    
    @Published public var showFloatingWidgetHotkey: HotKey? {
        didSet {
            saveHotkey("ShowFloatingWidget", hotkey: showFloatingWidgetHotkey)
        }
    }
    
    @Published public var showMainWindowHotkey: HotKey? {
        didSet {
            saveHotkey("ShowMainWindow", hotkey: showMainWindowHotkey)
        }
    }
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Callbacks
    
    public var onToggleRecording: (() -> Void)?
    public var onShowFloatingWidget: (() -> Void)?
    public var onShowMainWindow: (() -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        loadSavedHotkeys()
        setupHotkeyHandlers()
    }
    
    // MARK: - Public Methods
    
    public func setToggleRecordingHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        toggleRecordingHotkey?.isPaused = true
        toggleRecordingHotkey = HotKey(key: key, modifiers: modifiers)
        setupHotkeyHandlers()
    }
    
    public func setShowFloatingWidgetHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        showFloatingWidgetHotkey?.isPaused = true
        showFloatingWidgetHotkey = HotKey(key: key, modifiers: modifiers)
        setupHotkeyHandlers()
    }
    
    public func setShowMainWindowHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        showMainWindowHotkey?.isPaused = true
        showMainWindowHotkey = HotKey(key: key, modifiers: modifiers)
        setupHotkeyHandlers()
    }
    
    public func clearHotkey(for action: HotkeyAction) {
        switch action {
        case .toggleRecording:
            toggleRecordingHotkey?.isPaused = true
            toggleRecordingHotkey = nil
        case .showFloatingWidget:
            showFloatingWidgetHotkey?.isPaused = true
            showFloatingWidgetHotkey = nil
        case .showMainWindow:
            showMainWindowHotkey?.isPaused = true
            showMainWindowHotkey = nil
        }
    }
    
    public func pauseAllHotkeys() {
        toggleRecordingHotkey?.isPaused = true
        showFloatingWidgetHotkey?.isPaused = true
        showMainWindowHotkey?.isPaused = true
    }
    
    public func resumeAllHotkeys() {
        toggleRecordingHotkey?.isPaused = false
        showFloatingWidgetHotkey?.isPaused = false
        showMainWindowHotkey?.isPaused = false
    }
    
    public func resetToDefaults() {
        // Default: Command + Option + Space for toggle recording
        setToggleRecordingHotkey(key: .space, modifiers: [.command, .option])
        
        // Default: Command + Option + W for floating widget
        setShowFloatingWidgetHotkey(key: .w, modifiers: [.command, .option])
        
        // Default: Command + Option + M for main window
        setShowMainWindowHotkey(key: .m, modifiers: [.command, .option])
    }
    
    // MARK: - Private Methods
    
    private func setupHotkeyHandlers() {
        toggleRecordingHotkey?.keyDownHandler = { [weak self] in
            self?.onToggleRecording?()
        }
        
        showFloatingWidgetHotkey?.keyDownHandler = { [weak self] in
            self?.onShowFloatingWidget?()
        }
        
        showMainWindowHotkey?.keyDownHandler = { [weak self] in
            self?.onShowMainWindow?()
        }
    }
    
    private func loadSavedHotkeys() {
        // Load toggle recording hotkey
        if let toggleData = defaults.data(forKey: "HotkeyToggleRecording"),
           let hotkey = try? JSONDecoder().decode(HotkeyData.self, from: toggleData) {
            toggleRecordingHotkey = HotKey(key: hotkey.key, modifiers: hotkey.modifiers)
        } else {
            // Default hotkey
            toggleRecordingHotkey = HotKey(key: .space, modifiers: [.command, .option])
        }
        
        // Load floating widget hotkey
        if let widgetData = defaults.data(forKey: "HotkeyShowFloatingWidget"),
           let hotkey = try? JSONDecoder().decode(HotkeyData.self, from: widgetData) {
            showFloatingWidgetHotkey = HotKey(key: hotkey.key, modifiers: hotkey.modifiers)
        } else {
            // Default hotkey
            showFloatingWidgetHotkey = HotKey(key: .w, modifiers: [.command, .option])
        }
        
        // Load main window hotkey
        if let windowData = defaults.data(forKey: "HotkeyShowMainWindow"),
           let hotkey = try? JSONDecoder().decode(HotkeyData.self, from: windowData) {
            showMainWindowHotkey = HotKey(key: hotkey.key, modifiers: hotkey.modifiers)
        } else {
            // Default hotkey
            showMainWindowHotkey = HotKey(key: .m, modifiers: [.command, .option])
        }
    }
    
    private func saveHotkey(_ key: String, hotkey: HotKey?) {
        guard let hotkey = hotkey else {
            defaults.removeObject(forKey: "Hotkey\(key)")
            return
        }
        
        let hotkeyData = HotkeyData(key: hotkey.key, modifiers: hotkey.modifiers)
        if let data = try? JSONEncoder().encode(hotkeyData) {
            defaults.set(data, forKey: "Hotkey\(key)")
        }
    }
}

// MARK: - Supporting Types

public enum HotkeyAction: String, CaseIterable {
    case toggleRecording = "Toggle Recording"
    case showFloatingWidget = "Show Floating Widget"
    case showMainWindow = "Show Main Window"
}

private struct HotkeyData: Codable {
    let keyCode: UInt16
    let modifierFlags: UInt
    
    var key: Key {
        Key(carbonKeyCode: keyCode)
    }
    
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags)
    }
    
    init(key: Key, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = key.carbonKeyCode
        self.modifierFlags = modifiers.rawValue
    }
}

// MARK: - Extensions

extension Key {
    var displayName: String {
        switch self {
        case .space: return "Space"
        case .return: return "Return"
        case .tab: return "Tab"
        case .escape: return "Escape"
        case .delete: return "Delete"
        case .forwardDelete: return "Forward Delete"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
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
        default:
            // For letter keys, use the character
            let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            
            if let data = layoutData {
                let keyboardLayout = unsafeBitCast(data, to: CFData.self)
                var length = 0
                var deadKeyState: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                
                let result = UCKeyTranslate(
                    CFDataGetBytePtr(keyboardLayout).assumingMemoryBound(to: UCKeyboardLayout.self),
                    carbonKeyCode,
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    4,
                    &length,
                    &chars
                )
                
                if result == noErr && length > 0 {
                    return String(utf16CodeUnits: chars, count: length).uppercased()
                }
            }
            
            return "Key \(carbonKeyCode)"
        }
    }
}

extension NSEvent.ModifierFlags {
    var displayNames: [String] {
        var names: [String] = []
        
        if contains(.control) { names.append("⌃") }
        if contains(.option) { names.append("⌥") }
        if contains(.shift) { names.append("⇧") }
        if contains(.command) { names.append("⌘") }
        
        return names
    }
    
    var displayString: String {
        displayNames.joined()
    }
}