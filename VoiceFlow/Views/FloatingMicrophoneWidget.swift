import SwiftUI
import AppKit

/// Floating microphone widget for global transcription
/// Activated by hotkey, shows audio levels, enables global transcription
@MainActor
public class FloatingMicrophoneWidget: NSObject, ObservableObject {

    // MARK: - Properties

    @Published public var isVisible = false
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0
    @Published public var transcriptionText = ""
    @Published public var connectionStatus = "Ready"

    private var window: NSWindow?
    private var hostingView: NSHostingView<FloatingMicContent>?

    // Dependencies
    private let viewModel: SimpleTranscriptionViewModel
    private var globalTextInputCoordinator: GlobalTextInputCoordinator?

    // MARK: - Initialization

    public init(viewModel: SimpleTranscriptionViewModel) {
        self.viewModel = viewModel
        super.init()
        setupWindow()
        setupBindings()
        print("🎤 FloatingMicrophoneWidget initialized")
    }

    // MARK: - Public Methods

    /// Show the floating widget
    public func show() {
        guard let window = window else { return }

        isVisible = true

        // Position near cursor or center of screen
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let widgetSize = CGSize(width: 200, height: 120)
        let xPosition = min(
            max(mouseLocation.x - widgetSize.width/2, 50),
            screenFrame.width - widgetSize.width - 50
        )
        let yPosition = min(
            max(mouseLocation.y - widgetSize.height/2, 50),
            screenFrame.height - widgetSize.height - 50
        )

        window.setFrame(
            NSRect(x: xPosition, y: yPosition, width: widgetSize.width, height: widgetSize.height),
            display: true
        )
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        print("🎤 Floating widget shown at (\(xPosition), \(yPosition))")
    }

    /// Hide the floating widget
    public func hide() {
        isVisible = false
        window?.orderOut(nil)

        // Stop recording if active
        if isRecording {
            stopRecording()
        }

        print("🎤 Floating widget hidden")
    }

    /// Toggle widget visibility
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Start recording with global transcription
    public func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        transcriptionText = ""

        // Enable global input mode if not already enabled
        if !viewModel.globalInputEnabled {
            viewModel.enableGlobalInputMode()
        }

        Task {
            await viewModel.startRecording()
        }

        print("🎤 Floating widget recording started")
    }

    /// Stop recording and insert text globally
    public func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        viewModel.stopRecording()

        // Insert transcription globally if we have text
        if !transcriptionText.isEmpty {
            Task {
                let result = await globalTextInputCoordinator?.insertText(transcriptionText, isFinal: true)
                print("🎤 Global text insertion result: \(String(describing: result))")
            }
        }

        print("🎤 Floating widget recording stopped")
    }

    /// Toggle recording state
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Private Methods

    private func setupWindow() {
        let contentView = FloatingMicContent(widget: self)
        hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window?.contentView = hostingView
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = true
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window?.isMovableByWindowBackground = true
    }

    private func setupBindings() {
        // Create global text input coordinator with shared app state
        globalTextInputCoordinator = GlobalTextInputCoordinator(appState: AppState.shared)

        // Bind to viewModel properties
        viewModel.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        viewModel.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        viewModel.$transcriptionText
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcriptionText)

        viewModel.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
    }
}

// MARK: - SwiftUI Content View

public struct FloatingMicContent: View {
    @ObservedObject var widget: FloatingMicrophoneWidget

    public var body: some View {
        VStack(spacing: 12) {
            // Header with status
            HStack {
                Circle()
                    .fill(connectionStatusColor(for: widget.connectionStatus))
                    .frame(width: 8, height: 8)

                Text(widget.connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: widget.hide) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Main microphone button with audio level
            Button(action: widget.toggleRecording) {
                ZStack {
                    // Background circle with audio level animation
                    Circle()
                        .fill(widget.isRecording ? .red.opacity(0.2) : .blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .scaleEffect(widget.isRecording ? (1.0 + Double(widget.audioLevel) * 0.3) : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: widget.audioLevel)

                    // Microphone icon
                    Image(systemName: widget.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(widget.isRecording ? .red : .blue)
                }
            }
            .buttonStyle(.plain)
            .help(widget.isRecording ? "Stop Recording" : "Start Recording")

            // Audio level indicator
            if widget.isRecording {
                ProgressView(value: widget.audioLevel, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 4)
                    .padding(.horizontal, 8)
            }

            // Transcription preview
            if !widget.transcriptionText.isEmpty {
                Text(widget.transcriptionText.prefix(30) + (widget.transcriptionText.count > 30 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onHover { _ in
            NSCursor.pointingHand.set()
        }
    }

    private func connectionStatusColor(for status: String) -> Color {
        switch status {
        case "Connected": return .green
        case "Connecting": return .orange
        case "Reconnecting": return .yellow
        case "Error": return .red
        default: return .gray
        }
    }
}
