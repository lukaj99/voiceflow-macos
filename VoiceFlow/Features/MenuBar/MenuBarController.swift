import AppKit
import SwiftUI
import HotKey
import Combine

public final class MenuBarController: NSObject {
    // MARK: - Tag Constants
    
    public enum Tags {
        static let startStop = 1
        static let settings = 2
        static let quit = 3
        static let error = 4
    }
    
    // MARK: - Properties
    
    public let statusItem: NSStatusItem
    public let menu = NSMenu()
    public private(set) var hotKey: HotKey?
    
    private let viewModel: TranscriptionViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks for testing
    var onSettingsOpen: (() -> Void)?
    var onQuit: (() -> Void)?
    
    // Animation
    private var audioLevelTask: Task<Void, Never>?
    private let audioLevelFrames: [String] = [
        "mic.circle",
        "mic.circle.fill"
    ]
    
    // MARK: - Initialization
    
    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        super.init()
        
        setupMenu()
        setupBindings()
        registerGlobalHotkey()
    }
    
    deinit {
        audioLevelTask?.cancel()
    }
    
    // MARK: - Setup
    
    @MainActor private func setupMenu() {
        // Configure status item button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "VoiceFlow")
            button.target = self
            button.action = #selector(toggleMenu)
            button.setAccessibilityLabel("VoiceFlow Transcription")
        }
        
        // Build menu
        rebuildMenu()
        
        // Set menu
        statusItem.menu = menu
    }
    
    private func rebuildMenu() {
        menu.removeAllItems()
        
        // Start/Stop item
        let startStopItem = NSMenuItem(
            title: viewModel.isTranscribing ? "Stop Transcription" : "Start Transcription",
            action: #selector(toggleTranscription),
            keyEquivalent: ""
        )
        startStopItem.target = self
        startStopItem.tag = Tags.startStop
        startStopItem.accessibilityLabel = viewModel.isTranscribing ? "Stop transcription" : "Start transcription"
        menu.addItem(startStopItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.tag = Tags.settings
        settingsItem.accessibilityLabel = "Open settings"
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit VoiceFlow",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.tag = Tags.quit
        quitItem.accessibilityLabel = "Quit VoiceFlow"
        menu.addItem(quitItem)
    }
    
    private func setupBindings() {
        // Update menu when transcription state changes
        viewModel.$isTranscribing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems()
            }
            .store(in: &cancellables)
        
        // Animate icon based on audio level
        viewModel.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.updateAudioLevelAnimation(level: level)
            }
            .store(in: &cancellables)
        
        // Handle errors
        viewModel.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Global Hotkey
    
    @discardableResult
    public func registerGlobalHotkey() -> Bool {
        // Command + Option + Space
        hotKey = HotKey(key: .space, modifiers: [.command, .option])
        
        hotKey?.keyDownHandler = { [weak self] in
            self?.handleHotkeyPress()
        }
        
        return hotKey != nil
    }
    
    func handleHotkeyPress() {
        toggleTranscription(nil)
    }
    
    // MARK: - Menu Updates
    
    func updateMenuItems() {
        // Update start/stop item
        if let startStopItem = menu.item(withTag: Tags.startStop) {
            startStopItem.title = viewModel.isTranscribing ? "Stop Transcription" : "Start Transcription"
            startStopItem.accessibilityLabel = viewModel.isTranscribing ? "Stop transcription" : "Start transcription"
        }
        
        // Update icon
        updateStatusIcon()
    }
    
    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        
        let symbolName = viewModel.isTranscribing ? "mic.circle.fill" : "mic.circle"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoiceFlow")
        
        // Update color when transcribing
        if viewModel.isTranscribing {
            button.contentTintColor = .systemRed
        } else {
            button.contentTintColor = nil
        }
    }
    
    @MainActor
    private func updateAudioLevelAnimation(level: Float) {
        guard viewModel.isTranscribing else {
            audioLevelTask?.cancel()
            audioLevelTask = nil
            return
        }
        
        // Start animation if not running
        if audioLevelTask == nil && level > 0.1 {
            startAudioLevelAnimation()
        } else if audioLevelTask != nil && level < 0.1 {
            // Stop animation if audio level is too low
            audioLevelTask?.cancel()
            audioLevelTask = nil
            updateStatusIcon()
        }
    }
    
    @MainActor
    private func startAudioLevelAnimation() {
        audioLevelTask = Task { @MainActor in
            var frameIndex = 0
            
            while !Task.isCancelled && viewModel.isTranscribing {
                guard let button = statusItem.button else { break }
                
                // Alternate between filled and unfilled based on audio level
                let shouldFill = viewModel.currentAudioLevel > 0.3
                let symbolName = shouldFill ? "mic.circle.fill" : "mic.circle"
                
                button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoiceFlow")
                frameIndex = (frameIndex + 1) % 2
                
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }
    
    // MARK: - Error Handling
    
    func showError(_ error: any Error) {
        // Remove existing error items
        menu.items.removeAll { $0.tag == Tags.error }
        
        // Add error item at the top
        let errorItem = NSMenuItem(
            title: "⚠️ \(error.localizedDescription)",
            action: nil,
            keyEquivalent: ""
        )
        errorItem.tag = Tags.error
        errorItem.isEnabled = false
        
        menu.insertItem(errorItem, at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)
        
        // Auto-remove after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.menu.items.removeAll { $0.tag == Tags.error }
            // Remove separator if it's the first item after error removal
            if self?.menu.item(at: 0)?.isSeparatorItem == true {
                self?.menu.removeItem(at: 0)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleMenu(_ sender: Any?) {
        // Menu is shown automatically by NSStatusItem
    }
    
    @objc func toggleTranscription(_ sender: Any?) {
        Task {
            if viewModel.isTranscribing {
                await viewModel.stopTranscription()
            } else {
                await viewModel.startTranscription()
            }
        }
    }
    
    @MainActor @objc func openSettings(_ sender: Any?) {
        onSettingsOpen?()
        
        // Open settings window
        if let settingsWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            // Create and show settings window
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.title = "VoiceFlow Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @MainActor @objc func quit(_ sender: Any?) {
        onQuit?()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - SwiftUI Settings View Placeholder
// Note: Real SettingsView is defined in Features/Settings/SettingsView.swift