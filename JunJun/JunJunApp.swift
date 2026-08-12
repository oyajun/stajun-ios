import SwiftUI
import GoogleMobileAds

@main
struct JunJunApp: App {
    @State private var appState = AppState()

    init() {
        if Config.showAds {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
