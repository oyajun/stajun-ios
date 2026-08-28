import SwiftUI
import UIKit

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

    /// Convert Color to "#RRGGBB" hex string
    func toHex() -> String? {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uic.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", max(0, min(255, ri)), max(0, min(255, gi)), max(0, min(255, bi)))
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

        var h: Double = 0.08
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

        // Use balanced saturation and brightness for clear but soft visibility
        let glowSat: Double = 0.75
        let glowBri: Double = 1.0

        // Offsets around the base hue to form a seamless rotating loop
        let offsets: [Double] = [-0.07, -0.035, 0.0, 0.035, 0.07, 0.035, 0.0, -0.035, -0.07]

        return offsets.map { offset in
            var newHue = (h + offset).truncatingRemainder(dividingBy: 1.0)
            if newHue < 0 { newHue += 1.0 }
            return Color(hue: newHue, saturation: glowSat, brightness: glowBri)
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
        // Reds & Oranges
        "#FF3B30", "#FF6D00", "#FFD600", "#FFF9C4",
        // Pinks & Purples
        "#FF4081", "#FF10F0", "#F8BBD0", "#9C27B0", "#E1BEE7",
        // Blues & Cyans
        "#007AFF", "#3D5AFE", "#00E5FF", "#00ACC1", "#B3E5FC",
        // Greens & Limes
        "#00C853", "#76FF03", "#C8E6C9",
        // Earth & Neutrals
        "#D7CCC8", "#8D6E63", "#212121"
    ]

    static let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
    ]

    static func randomColor() -> String {
        colors.randomElement() ?? "#FFD54F"
    }
}

// MARK: - UserIconView

struct UserIconView: View {
    let emoji: String
    let backgroundColor: String
    var size: CGFloat = 44
    var isStudying: Bool = false
    var isPro: Bool = false

    @State private var rotation: Double = 0

    private var bgColor: Color {
        Color(hex: backgroundColor) ?? .orange
    }

    private var glowColors: [Color] {
        if isPro {
            return IconPresets.rainbowColors
        }
        return Color.neighboringColors(from: backgroundColor)
    }

    var body: some View {
        ZStack {
            if isStudying {
                // Soft spinning glow around the icon
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: glowColors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: size * 0.22
                    )
                    .frame(width: size * 1.32, height: size * 1.32)
                    .drawingGroup() // Offload rendering pass to Metal (GPU)
                    .blur(radius: size * 0.11)
                    .opacity(0.80)
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

    @State private var searchText = ""
    @State private var activeCategory: EmojiCategory = .smileys

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 6)]

    private var searchResults: [String]? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return EmojiCatalog.search(query: trimmed)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Search emoji", text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let results = searchResults {
                // Search Results View
                if results.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No emojis found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(results, id: \.self) { emoji in
                                emojiButton(emoji)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Category Bar & Paged Category View
                VStack(spacing: 3) {
                    // Category selector bar
                    HStack(spacing: 4) {
                        ForEach(EmojiCategory.allCases) { cat in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeCategory = cat
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(cat.symbol)
                                    .font(.system(size: 20))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        activeCategory == cat
                                            ? Color.accentColor.opacity(0.18)
                                            : Color(uiColor: .secondarySystemFill).opacity(0.4)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                activeCategory == cat ? Color.accentColor : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Category Title
                    HStack {
                        Text(LocalizedStringKey(activeCategory.title))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 1)

                    // Paged Emoji Grid
                    TabView(selection: $activeCategory) {
                        ForEach(EmojiCategory.allCases) { cat in
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(EmojiCatalog.emojis(for: cat), id: \.self) { emoji in
                                        emojiButton(emoji)
                                    }
                                }
                                .padding(.top, 1)
                                .padding(.bottom, 6)
                            }
                            .tag(cat)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(height: 480)
    }

    private func emojiButton(_ emoji: String) -> some View {
        Button {
            selected = emoji
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(
                    selected == emoji
                        ? Color.accentColor.opacity(0.20)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            selected == emoji ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ColorPresetPickerView

struct ColorPresetPickerView: View {
    @Binding var selected: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(IconPresets.colors, id: \.self) { hex in
                    colorButton(hex: hex)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .frame(height: 480)
    }

    private func colorButton(hex: String) -> some View {
        Button {
            selected = hex
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 42, height: 42)
                .overlay {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.20), lineWidth: 1)
                }
                .overlay {
                    if selected.caseInsensitiveCompare(hex) == .orderedSame {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2.5)
                            .padding(-3)
                    }
                }
        }
        .buttonStyle(.plain)
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
