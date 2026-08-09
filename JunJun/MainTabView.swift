import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Stats", systemImage: "chart.bar", value: .stats) {
                StatsView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .overlay {
            if appState.isStudying {
                StudyingBorderOverlay()
            }
        }
    }
}

// MARK: - Studying Border Overlay

private struct StudyingBorderOverlay: View {
    @State private var rotation: Double = 0

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
    ]

    var body: some View {
        GeometryReader { _ in
            let radius = displayCornerRadius()
            let gradient = AngularGradient(
                colors: colors,
                center: .center,
                startAngle: .degrees(rotation),
                endAngle: .degrees(rotation + 360)
            )
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(gradient, lineWidth: 24)
                    .blur(radius: 14)
                    .opacity(0.55)
                // Sharp inner rim
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(gradient, lineWidth: 2)
                    .opacity(0.85)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private func displayCornerRadius() -> CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
        return (screen?.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 44
    }
}

private enum MainTab: Hashable {
    case home
    case stats
    case search
    case settings
}

#Preview {
    MainTabView()
        .environment(AppState())
}
