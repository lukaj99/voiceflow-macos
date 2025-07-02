import Foundation
import Combine
import AppKit
import HotKey

/// Protocol defining the interface for managing global hotkeys
@MainActor
public protocol HotkeyServiceProtocol: AnyObject, ObservableObject, Sendable {
    
    // MARK: - Hotkey Properties
    
    var toggleRecordingHotkey: HotKey? { get set }
    var showFloatingWidgetHotkey: HotKey? { get set }
    var showMainWindowHotkey: HotKey? { get set }
    
    // MARK: - Callbacks
    
    var onToggleRecording: (() -> Void)? { get set }
    var onShowFloatingWidget: (() -> Void)? { get set }
    var onShowMainWindow: (() -> Void)? { get set }
    
    // MARK: - Hotkey Configuration
    
    func setToggleRecordingHotkey(key: Key, modifiers: NSEvent.ModifierFlags)
    func setShowFloatingWidgetHotkey(key: Key, modifiers: NSEvent.ModifierFlags)
    func setShowMainWindowHotkey(key: Key, modifiers: NSEvent.ModifierFlags)
    func clearHotkey(for action: HotkeyAction)
    
    // MARK: - Hotkey Management
    
    func pauseAllHotkeys()
    func resumeAllHotkeys()
    func resetToDefaults()
}

// MARK: - Hotkey Action Enum

public enum HotkeyAction: String, CaseIterable, Sendable {
    case toggleRecording = "Toggle Recording"
    case showFloatingWidget = "Show Floating Widget"
    case showMainWindow = "Show Main Window"
}