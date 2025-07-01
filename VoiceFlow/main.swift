import SwiftUI
import AppKit

// Main entry point for VoiceFlow Advanced
let app = NSApplication.shared
let delegate = AdvancedAppDelegate()
app.delegate = delegate
app.run()