import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = Config.adMobBannerUnitID) {
        self.adUnitID = adUnitID
    }

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = context.coordinator.getRootViewController()
        bannerView.delegate = context.coordinator
        
        let request = GADRequest()
        if !Config.adMobKeywords.isEmpty {
            request.keywords = Config.adMobKeywords
        }
        bannerView.load(request)
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // No dynamic update needed for standard fixed banner
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, GADBannerViewDelegate {
        func getRootViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes
            for scene in scenes {
                if let windowScene = scene as? UIWindowScene {
                    let state = windowScene.activationState
                    if state == .foregroundActive || state == .foregroundInactive {
                        for window in windowScene.windows {
                            if window.isKeyWindow {
                                return window.rootViewController
                            }
                        }
                    }
                }
            }
            return nil
        }
    }
}

/// Helper wrapper that checks `Config.showAds` and centers the 320x50 banner card
struct AdBannerCard: View {
    var body: some View {
        if Config.showAds {
            AdBannerView()
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
