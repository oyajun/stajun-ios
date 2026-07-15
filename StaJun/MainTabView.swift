import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Tab("ホーム", systemImage: "house") {
                HomeView()
            }
            Tab("検索", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("設定", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
