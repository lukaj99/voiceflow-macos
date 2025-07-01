import SwiftUI

/// Launch screen view displayed during app startup
public struct LaunchScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var isAnimationComplete = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Liquid glass background
            LiquidGlassBackground()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App icon/logo
                VStack(spacing: 20) {
                    // Microphone icon (simplified version of app icon)
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 45/255, green: 55/255, blue: 85/255),
                                        Color(red: 85/255, green: 45/255, blue: 130/255)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        // Microphone icon
                        VStack(spacing: 4) {
                            // Microphone body
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(width: 24, height: 36)
                            
                            // Microphone stand
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 3, height: 12)
                            
                            // Microphone base
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white)
                                .frame(width: 18, height: 4)
                        }
                        .offset(y: -2)
                        
                        // Sound waves
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 2, height: CGFloat(12 + index * 6))
                                    .offset(x: -45 + CGFloat(index * 8))
                                    .animation(
                                        .easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: isAnimationComplete
                                    )
                            }
                            
                            Spacer().frame(width: 90)
                            
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 2, height: CGFloat(18 - index * 6))
                                    .offset(x: 45 - CGFloat(index * 8))
                                    .animation(
                                        .easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: isAnimationComplete
                                    )
                            }
                        }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    // App name
                    Text("VoiceFlow")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 45/255, green: 55/255, blue: 85/255),
                                    Color(red: 85/255, green: 45/255, blue: 130/255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    // Tagline
                    Text("Professional Voice Transcription")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .opacity(textOpacity)
                    
                    Text("Initializing...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(textOpacity)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startLaunchAnimation()
        }
    }
    
    private func startLaunchAnimation() {
        // Logo scale and fade in
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Text fade in with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOpacity = 1.0
            }
        }
        
        // Start wave animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAnimationComplete = true
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenView()
        .frame(width: 800, height: 600)
}