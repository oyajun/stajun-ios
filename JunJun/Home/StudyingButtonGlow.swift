import SwiftUI

struct StudyingButtonGlow: View {
    var backgroundColor: String = "#FFD54F"
    var isPro: Bool = false
    @State private var rotation: Double = 0

    private var glowColors: [Color] {
        if isPro {
            return IconPresets.rainbowColors
        } else {
            return Color.neighboringColors(from: backgroundColor)
        }
    }

    var body: some View {
        let gradient = AngularGradient(
            colors: glowColors,
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )

        // Clean, single ambient glow behind the button matching screen edge glow intensity
        Capsule(style: .continuous)
            .fill(gradient)
            .padding(-8)
            .drawingGroup() // Offload rendering pass to Metal (GPU)
            .blur(radius: 16)
            .opacity(0.60)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
