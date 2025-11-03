import Foundation
import Combine

/// Coordinates global text input functionality with permission management
/// Single Responsibility: Global text input coordination and accessibility management
@MainActor
public class GlobalTextInputCoordinator: ObservableObject {

    // MARK: - Published Properties

    @Published public var isEnabled = false
    @Published public var hasPermissions = false
    @Published public var permissionError: String?
    @Published public var insertionCount: Int = 0
    @Published public var lastInsertionTime: Date?

    // MARK: - Dependencies

    private let globalTextInputService: GlobalTextInputService
    private let appState: AppState

    // MARK: - State

    private var hasInsertedTextInSession = false
    private var insertionHistory: [TextInsertion] = []

    // MARK: - Types

    public struct TextInsertion {
        public let id = UUID()
        public let text: String
        public let timestamp: Date
        public let success: Bool
        public let error: String?

        public init(text: String, timestamp: Date, success: Bool, error: String? = nil) {
            self.text = text
            self.timestamp = timestamp
            self.success = success
            self.error = error
        }
    }

    public enum InsertionResult {
        case success
        case permissionDenied
        case noActiveField
        case insertionFailed(any Error)
    }

    // MARK: - Initialization

    public init(
        globalTextInputService: GlobalTextInputService = GlobalTextInputService(),
        appState: AppState
    ) {
        self.globalTextInputService = globalTextInputService
        self.appState = appState

        updatePermissionStatus()

        print("🌐 GlobalTextInputCoordinator initialized")
    }

    // MARK: - Public Interface

    /// Enable global text input with permission check
    public func enableGlobalInput() {
        print("🌐 Requesting global text input permissions...")

        // Request accessibility permissions
        globalTextInputService.requestAccessibilityPermissions()

        // Check permissions after brief delay for system dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updatePermissionStatus()

            if self.hasPermissions {
                self.isEnabled = true
                self.appState.globalInputEnabled = true
                self.clearError()
                print("✅ Global text input enabled")
            } else {
                self.isEnabled = false
                self.appState.globalInputEnabled = false
                self.setPermissionError(
                    "Accessibility permissions required. Please grant permissions in System Settings > " +
                    "Privacy & Security > Accessibility."
                )
                print("❌ Global text input failed: No permissions")
            }
        }
    }

    /// Disable global text input
    public func disableGlobalInput() {
        isEnabled = false
        appState.globalInputEnabled = false
        hasInsertedTextInSession = false
        clearError()
        print("🌐 Global text input disabled")
    }

    /// Insert text globally with proper spacing and error handling
    public func insertText(_ text: String, isFinal: Bool = true) async -> InsertionResult {
        guard isEnabled else {
            return .permissionDenied
        }

        guard hasPermissions else {
            setPermissionError("Accessibility permissions not granted")
            return .permissionDenied
        }

        // Only insert final transcripts globally to avoid spam
        guard isFinal else {
            return .success
        }

        do {
            // Add proper spacing for global insertion
            let textToInsert = hasInsertedTextInSession ? " \(text)" : text

            let result = await globalTextInputService.insertText(textToInsert)

            switch result {
            case .success:
                hasInsertedTextInSession = true
                insertionCount += 1
                lastInsertionTime = Date()

                // Record successful insertion
                let insertion = TextInsertion(
                    text: textToInsert,
                    timestamp: Date(),
                    success: true
                )
                addToHistory(insertion)

                print("📝 Text inserted globally: \(text)")
                return .success

            case .accessibilityDenied:
                setPermissionError("Accessibility permissions denied during insertion")
                disableGlobalInput()
                return .permissionDenied

            case .noActiveTextField:
                print("⚠️ No active text field found for global insertion")
                return .noActiveField

            case .insertionFailed(let error):
                setPermissionError("Text insertion failed: \(error.localizedDescription)")

                // Record failed insertion
                let insertion = TextInsertion(
                    text: textToInsert,
                    timestamp: Date(),
                    success: false,
                    error: error.localizedDescription
                )
                addToHistory(insertion)

                return .insertionFailed(error)
            }
        }
    }

    /// Check current permission status
    public func checkPermissions() {
        updatePermissionStatus()
    }

    /// Reset session state (call when starting new transcription session)
    public func resetSession() {
        hasInsertedTextInSession = false
        clearError()
        print("🌐 Global text input session reset")
    }

    /// Get insertion history for debugging/monitoring
    public func getInsertionHistory() -> [TextInsertion] {
        return insertionHistory
    }

    /// Clear insertion history
    public func clearHistory() {
        insertionHistory.removeAll()
        insertionCount = 0
        lastInsertionTime = nil
        print("🌐 Global text input history cleared")
    }

    /// Get insertion statistics
    public func getInsertionStatistics() -> InsertionStatistics {
        let successfulInsertions = insertionHistory.filter { $0.success }.count
        let failedInsertions = insertionHistory.filter { !$0.success }.count
        let successRate = insertionHistory.isEmpty ? 0.0 : Double(successfulInsertions) / Double(insertionHistory.count)

        return InsertionStatistics(
            totalInsertions: insertionHistory.count,
            successfulInsertions: successfulInsertions,
            failedInsertions: failedInsertions,
            successRate: successRate,
            lastInsertionTime: lastInsertionTime
        )
    }

    // MARK: - Private Methods

    private func updatePermissionStatus() {
        globalTextInputService.checkAccessibilityPermissions()
        hasPermissions = globalTextInputService.hasAccessibilityPermissions

        if !hasPermissions && isEnabled {
            isEnabled = false
            appState.globalInputEnabled = false
        }
    }

    private func setPermissionError(_ message: String) {
        permissionError = message
        print("⚠️ Global text input error: \(message)")
    }

    private func clearError() {
        permissionError = nil
    }

    private func addToHistory(_ insertion: TextInsertion) {
        insertionHistory.append(insertion)

        // Keep only recent insertions (last 100)
        if insertionHistory.count > 100 {
            insertionHistory.removeFirst(insertionHistory.count - 100)
        }
    }
}

// MARK: - Supporting Types

public struct InsertionStatistics {
    public let totalInsertions: Int
    public let successfulInsertions: Int
    public let failedInsertions: Int
    public let successRate: Double
    public let lastInsertionTime: Date?

    public init(
        totalInsertions: Int,
        successfulInsertions: Int,
        failedInsertions: Int,
        successRate: Double,
        lastInsertionTime: Date?
    ) {
        self.totalInsertions = totalInsertions
        self.successfulInsertions = successfulInsertions
        self.failedInsertions = failedInsertions
        self.successRate = successRate
        self.lastInsertionTime = lastInsertionTime
    }
}
