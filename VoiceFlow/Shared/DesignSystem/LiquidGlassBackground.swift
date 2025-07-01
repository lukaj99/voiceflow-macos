import SwiftUI

public struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase: Double = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Base gradient layer
            baseGradient
            
            // Glass effect overlay
            glassOverlay
            
            // Animated gradient blobs
            animatedBlobs
            
            // Edge highlight
            edgeHighlight
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animationPhase = 360
            }
        }
    }
    
    private var baseGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(hex: "1C1C1E"), Color(hex: "000000")] :
                [Color(hex: "F2F2F7"), Color(hex: "E5E5EA")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var glassOverlay: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.6)
    }
    
    private var animatedBlobs: some View {
        GeometryReader { geometry in
            ZStack {
                // Blob 1
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .position(
                        x: geometry.size.width * 0.3 + sin(animationPhase * .pi / 180) * 50,
                        y: geometry.size.height * 0.4 + cos(animationPhase * .pi / 180) * 30
                    )
                    .blur(radius: 20)
                
                // Blob 2
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.purple.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .position(
                        x: geometry.size.width * 0.7 + cos(animationPhase * .pi / 180) * 40,
                        y: geometry.size.height * 0.6 + sin(animationPhase * .pi / 180) * 40
                    )
                    .blur(radius: 15)
                
                // Blob 3
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.2),
                                Color.cyan.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .position(
                        x: geometry.size.width * 0.5 + sin(animationPhase * 1.5 * .pi / 180) * 60,
                        y: geometry.size.height * 0.3 + cos(animationPhase * 1.5 * .pi / 180) * 50
                    )
                    .blur(radius: 25)
            }
        }
    }
    
    private var edgeHighlight: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.3),
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .padding(1)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}