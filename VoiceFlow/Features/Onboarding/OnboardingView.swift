import SwiftUI
import AVFoundation

public struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var microphonePermissionGranted = false
    @State private var accessibilityPermissionGranted = false
    @State private var showingPermissionError = false
    
    private let totalPages = 5
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)
                
                featuresPage
                    .tag(1)
                
                microphonePermissionPage
                    .tag(2)
                
                accessibilityPermissionPage
                    .tag(3)
                
                completionPage
                    .tag(4)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: currentPage)
            
            // Navigation
            navigationBar
                .padding()
                .background(.ultraThinMaterial)
        }
        .frame(width: 600, height: 500)
        .background(LiquidGlassBackground())
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: currentPage == 0)
            
            // Welcome text
            VStack(spacing: 12) {
                Text("Welcome to VoiceFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Professional voice transcription for macOS")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Key features
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bolt.fill", text: "Real-time transcription with <50ms latency", color: .yellow)
                FeatureRow(icon: "lock.fill", text: "Privacy-first: Everything stays on your Mac", color: .green)
                FeatureRow(icon: "sparkles", text: "AI-powered accuracy and context awareness", color: .purple)
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    private var featuresPage: some View {
        VStack(spacing: 30) {
            Text("Powerful Features")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 60)
            
            // Feature grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                FeatureCard(
                    icon: "command",
                    title: "Global Hotkey",
                    description: "Press ⌘⌥Space anywhere to start transcribing",
                    color: .blue
                )
                
                FeatureCard(
                    icon: "menubar.dock.rectangle",
                    title: "Menu Bar Access",
                    description: "Always available from your menu bar",
                    color: .orange
                )
                
                FeatureCard(
                    icon: "rectangle.on.rectangle",
                    title: "Floating Widget",
                    description: "Draggable overlay for quick access",
                    color: .purple
                )
                
                FeatureCard(
                    icon: "brain",
                    title: "Smart Context",
                    description: "Adapts to your current application",
                    color: .green
                )
                
                FeatureCard(
                    icon: "square.and.arrow.up",
                    title: "Export Options",
                    description: "Save as TXT, MD, DOCX, or PDF",
                    color: .red
                )
                
                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Performance",
                    description: "Optimized for Apple Silicon",
                    color: .indigo
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var microphonePermissionPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: microphonePermissionGranted ? "checkmark.circle.fill" : "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(microphonePermissionGranted ? .green : .blue)
                .symbolEffect(.bounce, value: microphonePermissionGranted)
            
            // Title
            Text("Microphone Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Description
            Text("VoiceFlow needs access to your microphone to transcribe speech.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            // Permission button
            if !microphonePermissionGranted {
                Button(action: requestMicrophonePermission) {
                    Label("Grant Microphone Access", systemImage: "mic")
                        .frame(width: 250)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Microphone access granted")
                        .foregroundColor(.secondary)
                }
            }
            
            // Privacy note
            VStack(spacing: 8) {
                Label("Your privacy is protected", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Audio is processed locally on your Mac. Nothing is sent to the cloud.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
            }
            .padding(.top)
            
            Spacer()
        }
        .alert("Permission Required", isPresented: $showingPermissionError) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant microphone access in System Settings > Privacy & Security > Microphone")
        }
    }
    
    private var accessibilityPermissionPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: accessibilityPermissionGranted ? "checkmark.circle.fill" : "eye.circle")
                .font(.system(size: 80))
                .foregroundColor(accessibilityPermissionGranted ? .green : .orange)
                .symbolEffect(.bounce, value: accessibilityPermissionGranted)
            
            // Title
            Text("Context Awareness (Optional)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Description
            VStack(spacing: 12) {
                Text("Grant accessibility permission to enable context-aware transcription.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                Text("VoiceFlow can adapt to your current app for better accuracy.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Permission button
            if !accessibilityPermissionGranted {
                VStack(spacing: 12) {
                    Button(action: requestAccessibilityPermission) {
                        Label("Enable Context Awareness", systemImage: "eye")
                            .frame(width: 250)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    
                    Button("Skip for Now") {
                        currentPage = 4
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Context awareness enabled")
                        .foregroundColor(.secondary)
                }
            }
            
            // Examples
            HStack(spacing: 20) {
                ContextExample(app: "Xcode", benefit: "Swift keywords")
                ContextExample(app: "Mail", benefit: "Email formatting")
                ContextExample(app: "Teams", benefit: "Meeting notes")
            }
            .padding(.top)
            
            Spacer()
        }
    }
    
    private var completionPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .symbolEffect(.bounce)
            }
            
            // Completion text
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("VoiceFlow is ready to transcribe")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Quick tips
            VStack(alignment: .leading, spacing: 16) {
                QuickTip(
                    icon: "command",
                    text: "Press ⌘⌥Space to start transcribing"
                )
                
                QuickTip(
                    icon: "menubar.arrow.up.rectangle",
                    text: "Access VoiceFlow from the menu bar"
                )
                
                QuickTip(
                    icon: "gearshape",
                    text: "Customize settings anytime"
                )
            }
            .padding(.horizontal, 100)
            
            // Start button
            Button(action: completeOnboarding) {
                Text("Start Using VoiceFlow")
                    .frame(width: 250)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack {
            // Skip button
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    currentPage = totalPages - 1
                }
                .buttonStyle(.link)
                .foregroundColor(.secondary)
            } else {
                Color.clear.frame(width: 50)
            }
            
            Spacer()
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            
            Spacer()
            
            // Next/Done button
            if currentPage < totalPages - 1 {
                Button("Next") {
                    withAnimation {
                        currentPage += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    (currentPage == 2 && !microphonePermissionGranted)
                )
            } else {
                Button("Done") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Actions
    
    private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                microphonePermissionGranted = granted
                if !granted {
                    showingPermissionError = true
                } else {
                    // Auto-advance to next page
                    withAnimation {
                        currentPage = 3
                    }
                }
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        accessibilityPermissionGranted = AXIsProcessTrustedWithOptions(options)
        
        if accessibilityPermissionGranted {
            withAnimation {
                currentPage = 4
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary)
        .cornerRadius(12)
    }
}

struct ContextExample: View {
    let app: String
    let benefit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(app)
                .font(.caption)
                .fontWeight(.medium)
            Text(benefit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary)
        .cornerRadius(8)
    }
}

struct QuickTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}