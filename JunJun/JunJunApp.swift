import SwiftUI
import GoogleMobileAds

@main
struct JunJunApp: App {
    @UIApplicationDelegateAdaptor(NotificationHandler.self) private var appDelegate
    @State private var appState = AppState()

    init() {
        SubscriptionManager.shared.initialize()

        if Config.showAds {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
                "abebb238e58136dd84e55df6f9fddec9"
            ]
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
