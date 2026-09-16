import SwiftUI
import GoogleMobileAds

final class BannerContainerView: UIView {
    weak var bannerView: GADBannerView?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            if bannerView?.rootViewController == nil {
                bannerView?.rootViewController = window.rootViewController ?? AdBannerView.Coordinator.findRootViewController()
            }
        }
    }
}

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    let adSize: GADAdSize
    /// キャッシュキーを指定すると AdBannerCache から既存のビューを再利用し、
    /// 再読み込みを防ぐ。nil の場合は毎回新規作成して即ロード。
    let cacheKey: String?
    var onAdLoaded: (() -> Void)? = nil
    var onAdFailed: ((Error) -> Void)? = nil

    init(
        adUnitID: String = Config.adMobBannerUnitID,
        adSize: GADAdSize = GADAdSizeMediumRectangle,
        cacheKey: String? = nil,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailed: ((Error) -> Void)? = nil
    ) {
        self.adUnitID = adUnitID
        self.adSize = adSize
        self.cacheKey = cacheKey
        self.onAdLoaded = onAdLoaded
        self.onAdFailed = onAdFailed
    }

    func makeUIView(context: Context) -> BannerContainerView {
        // SwiftUI には常に新鮮なコンテナを返す。
        // GADBannerView はコンテナのサブビューとして配置することで、
        // SwiftUI の Auto Layout リセットによる (0,0) フレーム問題を回避する。
        let container = BannerContainerView()
        container.backgroundColor = .clear

        let banner: GADBannerView
        let shouldLoad: Bool
        let currentState: BannerAdState

        if let key = cacheKey {
            let result = AdBannerCache.shared.banner(for: key, adUnitID: adUnitID, adSize: adSize)
            banner = result.view
            shouldLoad = result.isNew
            currentState = result.state
        } else {
            banner = GADBannerView(adSize: adSize)
            banner.adUnitID = adUnitID
            shouldLoad = true
            currentState = .loading
        }

        context.coordinator.parent = self
        banner.rootViewController = context.coordinator.getRootViewController()
        banner.delegate = context.coordinator

        // 既存の親から切り離してからコンテナに追加
        banner.removeFromSuperview()
        container.addSubview(banner)
        container.bannerView = banner

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
        } else if currentState == .success {
            DispatchQueue.main.async {
                self.onAdLoaded?()
            }
        }

        return container
    }

    func updateUIView(_ uiView: BannerContainerView, context: Context) {
        context.coordinator.parent = self
        if let banner = uiView.bannerView {
            if banner.rootViewController == nil {
                banner.rootViewController = context.coordinator.getRootViewController()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    class Coordinator: NSObject, GADBannerViewDelegate {
        var parent: AdBannerView

        init(parent: AdBannerView) {
            self.parent = parent
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            if let key = parent.cacheKey {
                AdBannerCache.shared.markLoaded(for: key)
            }
            parent.onAdLoaded?()
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[AdMob] Banner failed to load: \(error.localizedDescription)")
            #endif
            if let key = parent.cacheKey {
                AdBannerCache.shared.markFailed(for: key)
            }
            parent.onAdFailed?(error)
        }

        func getRootViewController() -> UIViewController? {
            Self.findRootViewController()
        }

        static func findRootViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                if let root = scene.keyWindow?.rootViewController {
                    return root
                }
                if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    return root
                }
                if let root = scene.windows.first?.rootViewController {
                    return root
                }
            }
            return nil
        }
    }
}

/// 広告右上に表示する × ボタン（タップすると JunJun Pro ペイウォールを表示）
struct AdCloseButton: View {
    var size: CGFloat = 24

    var body: some View {
        Button {
            SubscriptionManager.shared.showPaywall = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(Color(uiColor: .tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// タイムライン用の大型広告 (300×250 Medium Rectangle)
/// cacheKey を渡すことでスクロール復帰時の再読み込みを防ぐ
struct AdBannerCard: View {
    let cacheKey: String
    @Environment(AppState.self) private var appState
    @State private var isFailed: Bool = false

    var body: some View {
        if Config.showAds && !appState.isPro {
            if isFailed {
                if Config.isJapanRegion {
                    SpecialPromotionBannerCard(cacheKey: "fallback-\(cacheKey)")
                }
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    AdBannerView(
                        cacheKey: cacheKey,
                        onAdLoaded: {
                            isFailed = false
                        },
                        onAdFailed: { _ in
                            isFailed = true
                        }
                    )
                    .frame(width: 300, height: 250)

                    VStack(alignment: .trailing, spacing: 6) {
                        AdCloseButton()
                        Spacer()
                        AdBadge()
                    }
                    .frame(height: 250)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .onAppear {
                    if let state = AdBannerCache.shared.state(for: cacheKey), state == .failed {
                        isFailed = true
                    }
                }
            }
        }
    }
}

/// タイムライン最初の広告向けの中間バナー (320×100 Large Banner)
struct AdLargeBannerCard: View {
    let cacheKey: String
    @Environment(AppState.self) private var appState
    @State private var isFailed: Bool = false

    var body: some View {
        if Config.showAds && !appState.isPro {
            if isFailed {
                if Config.isJapanRegion {
                    SpecialPromotionBannerCard(cacheKey: "fallback-\(cacheKey)")
                }
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    AdBannerView(
                        adUnitID: Config.adMobBannerUnitID,
                        adSize: GADAdSizeLargeBanner,
                        cacheKey: cacheKey,
                        onAdLoaded: {
                            isFailed = false
                        },
                        onAdFailed: { _ in
                            isFailed = true
                        }
                    )
                    .frame(width: 320, height: 100)

                    VStack(alignment: .trailing, spacing: 6) {
                        AdCloseButton()
                        Spacer()
                        AdBadge()
                    }
                    .frame(height: 100)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .onAppear {
                    if let state = AdBannerCache.shared.state(for: cacheKey), state == .failed {
                        isFailed = true
                    }
                }
            }
        }
    }
}

/// Stats 画面など小さいスペース向けの通常バナー (320×50)
struct AdSmallBannerCard: View {
    @Environment(AppState.self) private var appState
    @State private var isLoaded: Bool = false
    @State private var isFailed: Bool = false

    var body: some View {
        if Config.showAds && !appState.isPro && !isFailed {
            HStack(alignment: .bottom, spacing: 2) {
                AdBannerView(
                    adUnitID: Config.adMobBannerUnitID,
                    adSize: GADAdSizeBanner,
                    onAdLoaded: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isLoaded = true
                        }
                    },
                    onAdFailed: { _ in
                        isFailed = true
                    }
                )
                // SE など幅が狭い端末でバッジが潰れないよう maxWidth で柔軟に
                .frame(minWidth: 0, idealWidth: 320, maxWidth: 320, minHeight: 50, maxHeight: 50)

                VStack(alignment: .trailing, spacing: 4) {
                    AdCloseButton()
                    Spacer()
                    AdBadge()
                }
                .frame(height: 50)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(isLoaded ? 1 : 0)
        }
    }
}

/// 広告バナーの右横に表示する水色バッジ
struct AdBadge: View {
    var body: some View {
        Text(LocalizedStringKey("Ad"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 0.0, green: 0.68, blue: 0.85), in: Capsule())
            .padding(.bottom, 2)
            .padding(.trailing, 4)
            .fixedSize()          // 潰れ防止: 常に intrinsic サイズを維持
            .layoutPriority(1)    // HStack 内でバナーより優先的にスペースを確保
    }
}
