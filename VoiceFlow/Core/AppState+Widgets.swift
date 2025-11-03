import Foundation

// MARK: - Floating Widget & Hotkey Management Extension

@MainActor
extension AppState {
    /// Setup floating widget and hotkey services
    internal func setupFloatingServices() {
        Task { @MainActor in
            setupFloatingWidget()
            setupHotkeys()
            print("🎤 Floating services initialized")
        }
    }

    /// Setup floating widget
    private func setupFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }

        // We'll need a ViewModel instance - for now create a simple one
        let viewModel = SimpleTranscriptionViewModel()
        floatingWidget = FloatingMicrophoneWidget(viewModel: viewModel)

        print("🎤 Floating widget created")
    }

    /// Setup global hotkeys
    private func setupHotkeys() {
        guard isGlobalHotkeysEnabled else { return }

        hotkeyService = GlobalHotkeyService()

        if let widget = floatingWidget {
            hotkeyService?.setFloatingWidget(widget)
        }

        print("⌨️ Global hotkeys configured")
    }

    /// Show floating widget
    public func showFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }

        floatingWidget?.show()
        isFloatingWidgetVisible = true
    }

    /// Hide floating widget
    public func hideFloatingWidget() {
        floatingWidget?.hide()
        isFloatingWidgetVisible = false
    }

    /// Toggle floating widget visibility
    public func toggleFloatingWidget() {
        if isFloatingWidgetVisible {
            hideFloatingWidget()
        } else {
            showFloatingWidget()
        }
    }

    /// Enable floating widget
    public func enableFloatingWidget() {
        guard !isFloatingWidgetEnabled else { return }

        isFloatingWidgetEnabled = true
        setupFloatingWidget()

        if let widget = floatingWidget {
            hotkeyService?.setFloatingWidget(widget)
        }

        print("🎤 Floating widget enabled")
    }

    /// Disable floating widget
    public func disableFloatingWidget() {
        guard isFloatingWidgetEnabled else { return }

        isFloatingWidgetEnabled = false
        hideFloatingWidget()

        print("🎤 Floating widget disabled")
    }

    /// Enable global hotkeys
    public func enableGlobalHotkeys() {
        guard !isGlobalHotkeysEnabled else { return }

        isGlobalHotkeysEnabled = true
        hotkeyService?.enable()

        print("⌨️ Global hotkeys enabled")
    }

    /// Disable global hotkeys
    public func disableGlobalHotkeys() {
        guard isGlobalHotkeysEnabled else { return }

        isGlobalHotkeysEnabled = false
        hotkeyService?.disable()

        print("⌨️ Global hotkeys disabled")
    }
}
