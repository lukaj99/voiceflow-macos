import SwiftUI
import AppKit

/// Window controller for the launch screen
public final class LaunchWindowController: NSWindowController {
    
    private var launchWindow: NSWindow?
    
    public override init(window: NSWindow?) {
        super.init(window: window)
        setupLaunchWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public convenience init() {
        self.init(window: nil)
    }
    
    private func setupLaunchWindow() {
        // Create launch screen content
        let launchView = LaunchScreenView()
        let hostingView = NSHostingView(rootView: launchView)
        
        // Create window
        launchWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        launchWindow?.contentView = hostingView
        launchWindow?.isReleasedWhenClosed = false
        launchWindow?.level = .floating
        launchWindow?.backgroundColor = .clear
        launchWindow?.isOpaque = false
        launchWindow?.hasShadow = true
        
        // Center window
        launchWindow?.center()
        
        self.window = launchWindow
    }
    
    public func showLaunchScreen() {
        launchWindow?.makeKeyAndOrderFront(nil)
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideLaunchScreen()
        }
    }
    
    public func hideLaunchScreen() {
        launchWindow?.orderOut(nil)
        launchWindow = nil
    }
}