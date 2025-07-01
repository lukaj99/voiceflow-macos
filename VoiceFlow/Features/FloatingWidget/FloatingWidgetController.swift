import AppKit
import SwiftUI
import Combine

public class FloatingWidgetController: NSObject {
    // MARK: - Properties
    
    public let window: FloatingWidgetWindow
    private let viewModel: TranscriptionViewModel
    private var hostingView: NSHostingView<FloatingWidgetView>?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    public var onWidgetClick: (() -> Void)?
    
    // MARK: - Initialization
    
    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
        self.window = FloatingWidgetWindow()
        
        super.init()
        
        setupWindow()
        setupBindings()
        restorePosition()
    }
    
    // Convenience init for app without view model
    public override convenience init() {
        self.init(viewModel: TranscriptionViewModel())
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Create SwiftUI view
        let widgetView = FloatingWidgetView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: widgetView)
        
        // Configure hosting view
        if let hostingView = hostingView {
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            window.contentView = hostingView
            
            // Make it clickable
            let clickGesture = NSClickGestureRecognizer(
                target: self,
                action: #selector(handleClick)
            )
            hostingView.addGestureRecognizer(clickGesture)
            
            // Add right-click menu
            hostingView.menu = createContextMenu()
            
            // Accessibility
            hostingView.setAccessibilityElement(true)
            hostingView.setAccessibilityRole(.group)
            hostingView.setAccessibilityLabel("VoiceFlow Widget")
        }
    }
    
    private func setupBindings() {
        // Auto-show when transcribing starts
        viewModel.$isTranscribing
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTranscribing in
                if isTranscribing && !(self?.window.isVisible ?? false) {
                    self?.show()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Position Management
    
    public func setPosition(_ position: FloatingWidgetPosition) {
        window.setPosition(position)
    }
    
    private func restorePosition() {
        let x = UserDefaults.standard.double(forKey: "FloatingWidgetX")
        let y = UserDefaults.standard.double(forKey: "FloatingWidgetY")
        
        if x != 0 || y != 0 {
            setPosition(.custom(CGPoint(x: x, y: y)))
        } else {
            // Default position
            setPosition(.topRight)
        }
    }
    
    // MARK: - Visibility
    
    public func show() {
        window.orderFront(nil)
        fadeIn()
    }
    
    public func hide() {
        fadeOut {
            self.window.orderOut(nil)
        }
    }
    
    public func toggleVisibility() {
        if window.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Animations
    
    public func fadeIn(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        window.alphaValue = 0
        window.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }, completionHandler: completion)
    }
    
    public func fadeOut(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: completion)
    }
    
    // MARK: - Interactions
    
    @objc func handleClick() {
        onWidgetClick?()
        
        // Default action: toggle transcription
        Task {
            if viewModel.isTranscribing {
                await viewModel.stopTranscription()
            } else {
                await viewModel.startTranscription()
            }
        }
    }
    
    public func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Toggle transcription
        let toggleItem = NSMenuItem(
            title: viewModel.isTranscribing ? "Stop Transcription" : "Start Transcription",
            action: #selector(toggleTranscription),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Position submenu
        let positionItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        let positionSubmenu = NSMenu()
        
        let positions: [(String, FloatingWidgetPosition)] = [
            ("Top Left", .topLeft),
            ("Top Center", .topCenter),
            ("Top Right", .topRight),
            ("Center", .center),
            ("Bottom Left", .bottomLeft),
            ("Bottom Center", .bottomCenter),
            ("Bottom Right", .bottomRight)
        ]
        
        for (title, position) in positions {
            let item = NSMenuItem(
                title: title,
                action: #selector(changePosition(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = position
            positionSubmenu.addItem(item)
        }
        
        positionItem.submenu = positionSubmenu
        menu.addItem(positionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Hide widget
        let hideItem = NSMenuItem(
            title: "Hide Widget",
            action: #selector(hide),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        return menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func toggleTranscription() {
        handleClick()
    }
    
    @objc private func changePosition(_ sender: NSMenuItem) {
        if let position = sender.representedObject as? FloatingWidgetPosition {
            setPosition(position)
        }
    }
    
    @objc private func openSettings() {
        // Open settings window
        NSApp.sendAction(#selector(MenuBarController.openSettings(_:)), to: nil, from: nil)
    }
    
    // MARK: - Cleanup
    
    deinit {
        window.close()
    }
}