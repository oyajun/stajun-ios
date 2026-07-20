import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Timeline", systemImage: "list.bullet.rectangle", value: .timeline) {
                PostTimelineView()
            }
            Tab("Stats", systemImage: "chart.bar", value: .stats) {
                StatsView()
            }
            Tab(value: .search, role: .search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
    }
}

private enum MainTab: Hashable {
    case home
    case timeline
    case stats
    case search
    case settings
}

#Preview {
    MainTabView()
        .environment(AppState())
}
