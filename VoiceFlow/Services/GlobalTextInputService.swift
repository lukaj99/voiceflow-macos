import Foundation
@preconcurrency import ApplicationServices
import AppKit

/// Service for inserting text globally at the current cursor location
/// Requires accessibility permissions to function properly
@MainActor
public class GlobalTextInputService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var hasAccessibilityPermissions = false
    @Published public var lastInsertionResult: InsertionResult?
    
    // MARK: - Public Types
    public enum InsertionResult {
        case success
        case accessibilityDenied
        case noActiveTextField
        case insertionFailed(any Error)
    }
    
    public enum InsertionMethod {
        case clipboard  // More reliable, uses pasteboard
        case keyEvents  // Direct key simulation
        case hybrid     // Try clipboard first, fallback to key events
    }
    
    // MARK: - Private Properties
    private var preferredInsertionMethod: InsertionMethod = .hybrid
    
    // MARK: - Initialization
    public init() {
        checkAccessibilityPermissions()
        print("🌐 GlobalTextInputService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Insert text at the current cursor location system-wide
    public func insertText(_ text: String, method: InsertionMethod? = nil) async -> InsertionResult {
        let insertionMethod = method ?? preferredInsertionMethod
        
        print("📝 Attempting to insert text globally: \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\"")
        
        // Check accessibility permissions first
        guard hasAccessibilityPermissions else {
            print("❌ Global text insertion failed: Accessibility permissions denied")
            let result = InsertionResult.accessibilityDenied
            lastInsertionResult = result
            return result
        }
        
        // Insert text using the specified method
        let result = await performTextInsertion(text, using: insertionMethod)
        lastInsertionResult = result
        
        switch result {
        case .success:
            print("✅ Text inserted successfully at cursor location")
        case .accessibilityDenied:
            print("❌ Text insertion failed: Accessibility denied")
        case .noActiveTextField:
            print("⚠️ Text insertion failed: No active text field found")
        case .insertionFailed(let error):
            print("❌ Text insertion failed: \(error.localizedDescription)")
        }
        
        return result
    }
    
    /// Request accessibility permissions from the user
    public func requestAccessibilityPermissions() {
        print("🔐 Requesting accessibility permissions...")
        
        // Check if already granted
        if AXIsProcessTrusted() {
            hasAccessibilityPermissions = true
            print("✅ Accessibility permissions already granted")
            return
        }
        
        // Request permissions with prompt - using nonisolated access
        Task.detached {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
            let options = [promptKey: true] as CFDictionary
            let granted = AXIsProcessTrustedWithOptions(options)
            
            await MainActor.run {
                self.hasAccessibilityPermissions = granted
                
                if granted {
                    print("✅ Accessibility permissions granted")
                } else {
                    print("⚠️ Accessibility permissions not yet granted - user will see system dialog")
                }
            }
        }
    }
    
    /// Check current accessibility permissions status
    public func checkAccessibilityPermissions() {
        hasAccessibilityPermissions = AXIsProcessTrusted()
        print("🔍 Accessibility permissions check: \(hasAccessibilityPermissions ? "✅ Granted" : "❌ Denied")")
    }
    
    /// Configure the preferred insertion method
    public func setInsertionMethod(_ method: InsertionMethod) {
        preferredInsertionMethod = method
        print("⚙️ Global text insertion method set to: \(method)")
    }
    
    // MARK: - Private Methods
    
    private func performTextInsertion(_ text: String, using method: InsertionMethod) async -> InsertionResult {
        switch method {
        case .clipboard:
            return await insertViaClipboard(text)
        case .keyEvents:
            return await insertViaKeyEvents(text)
        case .hybrid:
            // Try clipboard first, fallback to key events
            let clipboardResult = await insertViaClipboard(text)
            if case .success = clipboardResult {
                return clipboardResult
            }
            print("📋 Clipboard insertion failed, trying key events...")
            return await insertViaKeyEvents(text)
        }
    }
    
    private func insertViaClipboard(_ text: String) async -> InsertionResult {
        // Store current clipboard content
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)
        
        // Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V (paste)
        let success = await simulatePaste()
        
        // Restore previous clipboard content after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
        
        return success ? .success : .insertionFailed(NSError(domain: "GlobalTextInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Paste simulation failed"]))
    }
    
    private func insertViaKeyEvents(_ text: String) async -> InsertionResult {
        do {
            // Type each character
            for char in text {
                let success = await simulateKeyPress(for: char)
                if !success {
                    return .insertionFailed(NSError(domain: "GlobalTextInput", code: 2, userInfo: [NSLocalizedDescriptionKey: "Key simulation failed for character: \(char)"]))
                }
                
                // Small delay between characters for reliability
                try await Task.sleep(for: .milliseconds(10))
            }
            
            return .success
            
        } catch {
            return .insertionFailed(error)
        }
    }
    
    private func simulatePaste() async -> Bool {
        // Create Cmd+V key event
        guard let pasteKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),  // 'V' key
              let pasteKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            return false
        }
        
        // Add Command modifier
        pasteKeyDown.flags = .maskCommand
        pasteKeyUp.flags = .maskCommand
        
        // Post events
        pasteKeyDown.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(50))
        pasteKeyUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func simulateKeyPress(for character: Character) async -> Bool {
        let string = String(character)
        
        // Handle special characters
        if character == "\n" {
            // Return key
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false) else {
                return false
            }
            
            keyDown.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(20))
            keyUp.post(tap: .cghidEventTap)
            
            return true
        }
        
        // Regular character
        guard let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            return false
        }
        
        keyEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
        keyEvent.post(tap: .cghidEventTap)
        
        // Key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return false
        }
        
        keyUpEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
}

// MARK: - Extensions

extension GlobalTextInputService.InsertionMethod: CustomStringConvertible {
    public var description: String {
        switch self {
        case .clipboard: return "clipboard"
        case .keyEvents: return "keyEvents"
        case .hybrid: return "hybrid"
        }
    }
}