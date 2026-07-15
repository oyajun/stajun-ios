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
}

// MARK: - UserIconView

struct UserIconView: View {
    let emoji: String
    let backgroundColor: String
    var size: CGFloat = 44
    var isStudying: Bool = false

    @State private var pulse = false

    private var bgColor: Color {
        Color(hex: backgroundColor) ?? .orange
    }

    var body: some View {
        ZStack {
            if isStudying {
                Circle()
                    .fill(Color.yellow.opacity(0.35))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            Circle()
                .fill(bgColor)
                .frame(width: size, height: size)

            Text(emoji)
                .font(.system(size: size * 0.48))
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .onAppear { if isStudying { pulse = true } }
        .onChange(of: isStudying) { _, studying in
            pulse = studying
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
