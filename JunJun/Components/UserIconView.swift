import SwiftUI

// MARK: - Color Extension

extension Color {
    /// Create Color from a "#RRGGBB" format string
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >>  8) / 255.0,
            blue:  Double( rgb & 0x0000FF       ) / 255.0
        )
    }

    /// Generate an array of neighboring/analogous colors around a hex color for a spinning gradient
    static func neighboringColors(from hex: String) -> [Color] {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6,
              let rgb = UInt64(s, radix: 16) else {
            return [.orange, .yellow, .red, .orange]
        }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >>  8) / 255.0
        let b = Double( rgb & 0x0000FF       ) / 255.0

        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal

        var h: Double = 0
        if delta > 0 {
            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6.0
        }

        let sat = maxVal == 0 ? 0.0 : (delta / maxVal)
        let bri = maxVal

        // Smoothly balance saturation: lift pale colors (~0.52-0.58) without oversaturating deep colors (~0.65-0.70)
        let glowSat = min(0.50 + sat * 0.28, 0.72)
        // Ensure glowing luminance remains bright and light (not dark or muddy)
        let glowBri = max(bri, 0.94)

        // Offsets around the base hue to form a seamless rotating loop
        let offsets: [Double] = [-0.07, -0.035, 0.0, 0.035, 0.07, 0.035, 0.0, -0.035, -0.07]

        return offsets.map { offset in
            var newHue = (h + offset).truncatingRemainder(dividingBy: 1.0)
            if newHue < 0 { newHue += 1.0 }
            if sat < 0.08 {
                let briVar = min(max(bri + offset * 1.5, 0.4), 1.0)
                return Color(hue: h, saturation: 0, brightness: briVar)
            } else {
                return Color(hue: newHue, saturation: glowSat, brightness: glowBri)
            }
        }
    }
}

// MARK: - Preset Data

enum IconPresets {
    static let emojis: [String] = [
        "📚", "🔥", "💪", "🎯", "📝", "✏️",
        "🧠", "💡", "🎓", "🌱", "⚡", "🏆",
        "🎮", "🎨", "🎵", "🧪", "🔬", "💻",
        "📊", "🌟",
    ]

    static let colors: [String] = [
        "#FFD54F", "#B3E5FC", "#FFCCBC", "#C8E6C9",
        "#E1BEE7", "#FFF9C4", "#F8BBD0", "#B2EBF2",
        "#FFAB40", "#69F0AE", "#CE93D8", "#80DEEA",
        "#FF8A65", "#4DB6AC", "#7986CB", "#F06292",
    ]

    static let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
    ]
}

// MARK: - UserIconView

struct UserIconView: View {
    let emoji: String
    let backgroundColor: String
    var size: CGFloat = 44
    var isStudying: Bool = false

    @State private var rotation: Double = 0

    private var bgColor: Color {
        Color(hex: backgroundColor) ?? .orange
    }

    private var glowColors: [Color] {
        Color.neighboringColors(from: backgroundColor)
    }

    var body: some View {
        ZStack {
            if isStudying {
                // Soft spinning glow using a balanced gradient of neighboring colors around the icon's color
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: glowColors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: size * 0.20
                    )
                    .frame(width: size * 1.30, height: size * 1.30)
                    .drawingGroup() // Offload rendering pass to Metal (GPU)
                    .blur(radius: size * 0.15)
                    .opacity(0.72)

                /*
                // --- Rainbow glow (preserved) ---
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: IconPresets.rainbowColors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: size * 0.20
                    )
                    .frame(width: size * 1.25, height: size * 1.25)
                    .drawingGroup()
                    .blur(radius: size * 0.12)
                    .opacity(0.55)
                */
            }

            Circle()
                .fill(bgColor)
                .frame(width: size, height: size)

            Text(emoji)
                .font(.system(size: size * 0.48))
        }
        .frame(width: size, height: size)
        .onAppear {
            if isStudying { startRotation() }
        }
        .onChange(of: isStudying) { _, studying in
            if studying { startRotation() }
        }
    }

    private func startRotation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// MARK: - EmojiPickerView

struct EmojiPickerView: View {
    @Binding var selected: String

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(IconPresets.emojis, id: \.self) { emoji in
                Button {
                    selected = emoji
                } label: {
                    Text(emoji)
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(
                            selected == emoji
                                ? Color.accentColor.opacity(0.18)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    selected == emoji ? Color.accentColor : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ColorPresetPickerView

struct ColorPresetPickerView: View {
    @Binding var selected: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(IconPresets.colors, id: \.self) { hex in
                Button {
                    selected = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 40, height: 40)
                        .overlay {
                            if selected == hex {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 2.5)
                                    .padding(-3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            UserIconView(emoji: "📚", backgroundColor: "#FFD54F", size: 56, isStudying: true)
            UserIconView(emoji: "🔥", backgroundColor: "#FFCCBC", size: 56, isStudying: false)
        }
        EmojiPickerView(selected: .constant("📚"))
        ColorPresetPickerView(selected: .constant("#FFD54F"))
    }
    .padding()
}
