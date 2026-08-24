import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Stats", systemImage: "chart.bar", value: .stats) {
                StatsView()
            }
            Tab("Notifications", systemImage: "bell", value: .notifications) {
                NotificationsView()
            }
            .badge(appState.unreadNotificationCount)
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .task {
            await appState.fetchUnreadNotificationCount()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                if scenePhase == .active {
                    await appState.fetchUnreadNotificationCount()
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .notifications {
                Task { await appState.fetchUnreadNotificationCount() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appState.fetchUnreadNotificationCount() }
            }
        }
        .overlay {
            if appState.isStudying {
                StudyingBorderOverlay(
                    backgroundColor: appState.currentUser?.iconBackgroundColor ?? "#FFD54F"
                )
            }
        }
    }
}

// MARK: - Studying Border Overlay

private struct StudyingBorderOverlay: View {
    var backgroundColor: String = "#FFD54F"
    @State private var rotation: Double = 0
    @State private var cornerRadius: CGFloat = 44

    // Rainbow colors (preserved)
    private static let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
    ]

    private var glowColors: [Color] {
        Color.neighboringColors(from: backgroundColor)
    }

    var body: some View {
        GeometryReader { _ in
            let gradient = AngularGradient(
                colors: glowColors,
                center: .center,
                startAngle: .degrees(rotation),
                endAngle: .degrees(rotation + 360)
            )

            /*
            // --- Original Rainbow Gradient (Preserved) ---
            let rainbowGradient = AngularGradient(
                colors: Self.rainbowColors,
                center: .center,
                startAngle: .degrees(rotation),
                endAngle: .degrees(rotation + 360)
            )
            */

            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(gradient, lineWidth: 24)
                    .blur(radius: 14)
                    .opacity(0.60)
                // Sharp inner rim
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(gradient, lineWidth: 2)
                    .opacity(0.75)
            }
            .drawingGroup() // Offload rendering pass to Metal (GPU)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            cornerRadius = getDisplayCornerRadius()
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private func getDisplayCornerRadius() -> CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
        return (screen?.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 44
    }
}

private enum MainTab: Hashable {
    case home
    case stats
    case notifications
    case search
    case settings
}

#Preview {
    MainTabView()
        .environment(AppState())
}
