import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    let adSize: GADAdSize
    /// キャッシュキーを指定すると AdBannerCache から既存のビューを再利用し、
    /// 再読み込みを防ぐ。nil の場合は毎回新規作成して即ロード。
    let cacheKey: String?

    init(
        adUnitID: String = Config.adMobBannerUnitID,
        adSize: GADAdSize = GADAdSizeMediumRectangle,
        cacheKey: String? = nil
    ) {
        self.adUnitID = adUnitID
        self.adSize = adSize
        self.cacheKey = cacheKey
    }

    func makeUIView(context: Context) -> UIView {
        // SwiftUI には常に新鮮なコンテナを返す。
        // GADBannerView はコンテナのサブビューとして配置することで、
        // SwiftUI の Auto Layout リセットによる (0,0) フレーム問題を回避する。
        let container = UIView()
        container.backgroundColor = .clear

        let banner: GADBannerView
        let shouldLoad: Bool

        if let key = cacheKey {
            let result = AdBannerCache.shared.banner(for: key, adUnitID: adUnitID, adSize: adSize)
            banner = result.view
            shouldLoad = result.isNew
        } else {
            banner = GADBannerView(adSize: adSize)
            banner.adUnitID = adUnitID
            shouldLoad = true
        }

        banner.rootViewController = context.coordinator.getRootViewController()
        banner.delegate = context.coordinator

        // 既存の親から切り離してからコンテナに追加
        banner.removeFromSuperview()
        container.addSubview(banner)

        // 明示的なサイズ制約で (0,0) を防ぐ
        let adW = adSize.size.width > 0 ? adSize.size.width : 300
        let adH = adSize.size.height > 0 ? adSize.size.height : 250
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            banner.widthAnchor.constraint(equalToConstant: adW),
            banner.heightAnchor.constraint(equalToConstant: adH),
        ])

        if shouldLoad {
            // レイアウト前にフレームを明示してから load() を呼ぶ
            banner.frame = CGRect(x: 0, y: 0, width: adW, height: adH)
            let request = GADRequest()
            if !Config.adMobKeywords.isEmpty {
                request.keywords = Config.adMobKeywords
            }
            banner.load(request)
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // rootViewController が変わった場合のみ更新
        if let banner = uiView.subviews.first as? GADBannerView {
            banner.rootViewController = context.coordinator.getRootViewController()
        }
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

/// タイムライン用の大型広告 (300×250 Medium Rectangle)
/// cacheKey を渡すことでスクロール復帰時の再読み込みを防ぐ
struct AdBannerCard: View {
    let cacheKey: String

    var body: some View {
        if Config.showAds {
            AdBannerView(cacheKey: cacheKey)
                .frame(width: 300, height: 250)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// タイムライン最初の広告向けの中間バナー (320×100 Large Banner)
struct AdLargeBannerCard: View {
    let cacheKey: String

    var body: some View {
        if Config.showAds {
            AdBannerView(
                adUnitID: Config.adMobBannerUnitID,
                adSize: GADAdSizeLargeBanner,
                cacheKey: cacheKey
            )
            .frame(width: 320, height: 100)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Stats 画面など小さいスペース向けの通常バナー (320×50)
struct AdSmallBannerCard: View {
    var body: some View {
        if Config.showAds {
            AdBannerView(
                adUnitID: Config.adMobBannerUnitID,
                adSize: GADAdSizeBanner
            )
            .frame(width: 320, height: 50)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
