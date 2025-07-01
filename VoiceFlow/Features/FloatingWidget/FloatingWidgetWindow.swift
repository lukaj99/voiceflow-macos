import AppKit
import SwiftUI

public class FloatingWidgetWindow: NSPanel {
    // MARK: - Properties
    
    private let widgetSize = CGSize(width: 320, height: 100)
    private let edgePadding: CGFloat = 20
    
    // MARK: - Initialization
    
    public init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: widgetSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Window configuration
        isFloatingPanel = true
        level = .floating
        hasShadow = false // Custom shadow in view
        isOpaque = false
        backgroundColor = .clear
        
        // Behavior
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        
        // Collection behavior
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        // Animations
        animationBehavior = .documentWindow
    }
    
    // MARK: - Positioning
    
    public func setPosition(_ position: FloatingWidgetPosition) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        var origin: CGPoint
        
        switch position {
        case .topLeft:
            origin = CGPoint(
                x: edgePadding,
                y: screenFrame.maxY - frame.height - edgePadding
            )
        case .topCenter:
            origin = CGPoint(
                x: (screenFrame.width - frame.width) / 2,
                y: screenFrame.maxY - frame.height - edgePadding
            )
        case .topRight:
            origin = CGPoint(
                x: screenFrame.maxX - frame.width - edgePadding,
                y: screenFrame.maxY - frame.height - edgePadding
            )
        case .middleLeft:
            origin = CGPoint(
                x: edgePadding,
                y: (screenFrame.height - frame.height) / 2
            )
        case .center:
            origin = CGPoint(
                x: (screenFrame.width - frame.width) / 2,
                y: (screenFrame.height - frame.height) / 2
            )
        case .middleRight:
            origin = CGPoint(
                x: screenFrame.maxX - frame.width - edgePadding,
                y: (screenFrame.height - frame.height) / 2
            )
        case .bottomLeft:
            origin = CGPoint(
                x: edgePadding,
                y: edgePadding
            )
        case .bottomCenter:
            origin = CGPoint(
                x: (screenFrame.width - frame.width) / 2,
                y: edgePadding
            )
        case .bottomRight:
            origin = CGPoint(
                x: screenFrame.maxX - frame.width - edgePadding,
                y: edgePadding
            )
        case .custom(let point):
            origin = point
        }
        
        // Constrain to screen bounds
        origin = constrainToScreen(origin, in: screenFrame)
        setFrameOrigin(origin)
    }
    
    private func constrainToScreen(_ point: CGPoint, in screenFrame: CGRect) -> CGPoint {
        var constrainedPoint = point
        
        // Constrain X
        constrainedPoint.x = max(0, min(point.x, screenFrame.maxX - frame.width))
        
        // Constrain Y
        constrainedPoint.y = max(0, min(point.y, screenFrame.maxY - frame.height))
        
        return constrainedPoint
    }
    
    // MARK: - Overrides
    
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    
    public override func mouseDragged(with event: NSEvent) {
        // Allow dragging
        super.mouseDragged(with: event)
        
        // Save position after drag
        UserDefaults.standard.set(frame.origin.x, forKey: "FloatingWidgetX")
        UserDefaults.standard.set(frame.origin.y, forKey: "FloatingWidgetY")
    }
}

// MARK: - Floating Widget View

public struct FloatingWidgetView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var isHovered = false
    @State private var dragOffset = CGSize.zero
    
    public init(viewModel: TranscriptionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // Background with liquid glass effect
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 10,
                    x: 0,
                    y: 5
                )
            
            // Content
            HStack(spacing: 16) {
                // Microphone icon with state
                microphoneIcon
                
                // Waveform visualizer
                WaveformView(audioLevel: viewModel.currentAudioLevel)
                    .frame(width: 180, height: 40)
                
                // Status indicator
                statusIndicator
            }
            .padding(.horizontal, 20)
        }
        .frame(width: 320, height: 100)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VoiceFlow transcription widget")
        .accessibilityHint(viewModel.isTranscribing ? "Transcribing" : "Click to start transcription")
    }
    
    private var microphoneIcon: some View {
        Image(systemName: viewModel.isTranscribing ? "mic.circle.fill" : "mic.circle")
            .font(.system(size: 36))
            .foregroundColor(viewModel.isTranscribing ? .red : .secondary)
            .symbolEffect(.bounce, value: viewModel.isTranscribing)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 3)
                    .scaleEffect(viewModel.isTranscribing ? 1.5 : 1.0)
                    .opacity(viewModel.isTranscribing ? 0 : 1)
                    .animation(
                        viewModel.isTranscribing ?
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false) :
                            .default,
                        value: viewModel.isTranscribing
                    )
            )
    }
    
    private var statusColor: Color {
        if let error = viewModel.error {
            return .red
        } else if viewModel.isTranscribing {
            return .green
        } else {
            return .gray
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let audioLevel: Float
    @State private var wavePhase: Double = 0
    
    private let barCount = 20
    private let barSpacing: CGFloat = 3
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        height: barHeight(for: index, in: geometry.size),
                        phase: wavePhase,
                        delay: Double(index) * 0.05
                    )
                }
            }
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false)
                ) {
                    wavePhase = .pi * 2
                }
            }
        }
    }
    
    private func barHeight(for index: Int, in size: CGSize) -> CGFloat {
        let normalizedIndex = Double(index) / Double(barCount - 1)
        let sineValue = sin(normalizedIndex * .pi)
        let baseHeight = size.height * 0.3
        let variableHeight = size.height * 0.7 * sineValue * CGFloat(audioLevel)
        return baseHeight + variableHeight
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let phase: Double
    let delay: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.8),
                        Color.purple.opacity(0.6)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: height)
            .animation(
                .easeInOut(duration: 0.3).delay(delay),
                value: height
            )
    }
}