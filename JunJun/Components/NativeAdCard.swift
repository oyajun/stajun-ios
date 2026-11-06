import SwiftUI
import GoogleMobileAds

/// タイムライン用のネイティブ広告カード
/// UIレイアウト（アイコン、タイトル、PR表記、Adバッジ、×ボタン）を SwiftUI で構築し、
/// メディア（画像/動画）とCTAボタンを AdMob の GADNativeAdView とバインドして表示。
/// GADNativeAdView がメディア領域から始まるため、AdMob の AdChoices（iボタン）は画像/動画の右上に配置されます。
struct NativeAdCard: View {
    let cacheKey: String?
    let horizontalPadding: CGFloat
    @Environment(AppState.self) private var appState
    @State private var nativeAd: GADNativeAd?
    @State private var isFailed: Bool

    init(cacheKey: String? = nil, horizontalPadding: CGFloat = 26) {
        self.cacheKey = cacheKey
        self.horizontalPadding = horizontalPadding
        if let cacheKey {
            let cachedAd = AdNativeCache.shared.ad(for: cacheKey)
            let failed = AdNativeCache.shared.state(for: cacheKey) == .failed
            _nativeAd = State(initialValue: cachedAd)
            _isFailed = State(initialValue: cachedAd == nil && failed)
        } else {
            _nativeAd = State(initialValue: nil)
            _isFailed = State(initialValue: false)
        }
    }

    var body: some View {
        if Config.showAds && !appState.isPro {
            Group {
                if isFailed {
                    // ネイティブ広告が取得できなかった場合は、従来の AdMob バナーへフォールバック（340pt の中央に固定配置）
                    let fallbackKey = cacheKey.map { "banner-fallback-\($0)" }
                    AdBannerCard(cacheKey: fallbackKey)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let ad = nativeAd {
                    NativeAdContentView(nativeAd: ad)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    // ロード中プレースホルダー（チラつき・高さ変動防止）
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 340)
            .clipped()
            .task(id: cacheKey ?? "uncached") {
                loadNativeAd(for: cacheKey)
            }
            .onChange(of: cacheKey) { _, newKey in
                if let newKey {
                    nativeAd = AdNativeCache.shared.ad(for: newKey)
                    isFailed = (nativeAd == nil) && (AdNativeCache.shared.state(for: newKey) == .failed)
                } else {
                    nativeAd = nil
                    isFailed = false
                }
                loadNativeAd(for: newKey)
            }
        }
    }

    private func loadNativeAd(for targetKey: String?) {
        guard let targetKey else {
            guard nativeAd == nil && !isFailed else { return }
            AdNativeCache.shared.loadUncachedAd { result in
                switch result {
                case .success(let ad):
                    self.nativeAd = ad
                    self.isFailed = false
                case .failure:
                    self.nativeAd = nil
                    self.isFailed = true
                }
            }
            return
        }

        if let cached = AdNativeCache.shared.ad(for: targetKey) {
            self.nativeAd = cached
            self.isFailed = false
            return
        }

        if let state = AdNativeCache.shared.state(for: targetKey), state == .failed {
            self.nativeAd = nil
            self.isFailed = true
            return
        }

        AdNativeCache.shared.loadAd(for: targetKey) { result in
            guard self.cacheKey == targetKey else { return }
            switch result {
            case .success(let ad):
                self.nativeAd = ad
                self.isFailed = false
            case .failure:
                self.nativeAd = nil
                self.isFailed = true
            }
        }
    }
}

/// SwiftUI で構築したネイティブ広告カードのコンテンツビュー
struct NativeAdContentView: View {
    let nativeAd: GADNativeAd

    private var mediaContainerHeight: CGFloat {
        if let body = nativeAd.body, !body.isEmpty {
            return 268 // 180 (動画) + 8 + 34 (本文2行) + 8 + 38 (CTA)
        } else {
            return 226 // 180 (動画) + 8 + 38 (CTA)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー行 (SwiftUI: 高さを36ptに完全固定)
            HStack(alignment: .center, spacing: 8) {
                // アプリアイコン（存在する場合のみ表示、無ければ自動で左詰め）
                if let icon = nativeAd.icon?.image {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // タイトル + PR表記（1行固定で高さのブレを防止）
                VStack(alignment: .leading, spacing: 2) {
                    if let headline = nativeAd.headline {
                        Text(headline)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let advertiser = nativeAd.advertiser, !advertiser.isEmpty {
                        Text(String(format: NSLocalizedString("PR %@", comment: "PR advertiser label"), advertiser))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let store = nativeAd.store, !store.isEmpty {
                        Text(store)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                // 広告バッジ + X（閉じる）ボタン (SwiftUI)
                HStack(alignment: .center, spacing: 6) {
                    AdBadge()
                    AdCloseButton()
                }
            }
            .frame(height: 36)

            // メディア（動画/画像） + 本文 + 青いCTAボタン (GADNativeAdView)
            NativeAdMediaAndCTAViewRepresentable(nativeAd: nativeAd)
                .frame(height: mediaContainerHeight)
        }
    }
}

/// ダイアログ・シート下部用の細長い横並びネイティブ広告カード（左: 動画・画像 / 右: 文章・CTA）
struct CompactNativeAdCard: View {
    let cacheKey: String?
    let horizontalPadding: CGFloat
    @Environment(AppState.self) private var appState
    @State private var nativeAd: GADNativeAd?
    @State private var isFailed: Bool

    init(cacheKey: String? = nil, horizontalPadding: CGFloat = 0) {
        self.cacheKey = cacheKey
        self.horizontalPadding = horizontalPadding
        if let cacheKey {
            let cachedAd = AdNativeCache.shared.ad(for: cacheKey)
            let failed = AdNativeCache.shared.state(for: cacheKey) == .failed
            _nativeAd = State(initialValue: cachedAd)
            _isFailed = State(initialValue: cachedAd == nil && failed)
        } else {
            _nativeAd = State(initialValue: nil)
            _isFailed = State(initialValue: false)
        }
    }

    var body: some View {
        if Config.showAds && !appState.isPro {
            Group {
                if isFailed {
                    AdSmallBannerCard()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let ad = nativeAd {
                    ZStack(alignment: .topLeading) {
                        // 下層: GADNativeAdView（左150x124動画・画像メディア + 右上AdChoices(i) + 右側タップ判定）
                        CompactNativeAdViewRepresentable(nativeAd: ad)
                            .frame(maxWidth: .infinity)
                            .frame(height: 124)

                        // 上層右側: SwiftUI によるテキストレイアウト
                        VStack(alignment: .leading, spacing: 4) {
                            // 1行目（タイトルの一行上・右端）: [広告バッジ] + 右端の [i] 用スペース
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                AdBadge()
                                    .padding(.trailing, 32)
                            }
                            .frame(height: 18)

                            // 2行目: アイコン + タイトル(2行) + PR表記
                            HStack(alignment: .top, spacing: 6) {
                                if let icon = ad.icon?.image {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    if let headline = ad.headline {
                                        Text(headline)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }

                                    if let advertiser = ad.advertiser, !advertiser.isEmpty {
                                        Text(String(format: NSLocalizedString("PR %@", comment: "PR advertiser label"), advertiser))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else if let store = ad.store, !store.isEmpty {
                                        Text(store)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // 3行目: 本文
                            if let body = ad.body, !body.isEmpty {
                                Text(body)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 162) // 150pt (mediaView) + 12pt (spacing)
                        .frame(maxWidth: .infinity, maxHeight: 124, alignment: .topLeading)
                        .allowsHitTesting(false)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
            }
            .task(id: cacheKey ?? "uncached") {
                loadNativeAd(for: cacheKey)
            }
        }
    }

    private func loadNativeAd(for targetKey: String?) {
        guard let targetKey else {
            guard nativeAd == nil && !isFailed else { return }
            AdNativeCache.shared.loadUncachedAd { result in
                switch result {
                case .success(let ad):
                    self.nativeAd = ad
                    self.isFailed = false
                case .failure:
                    self.nativeAd = nil
                    self.isFailed = true
                }
            }
            return
        }

        if let cached = AdNativeCache.shared.ad(for: targetKey) {
            self.nativeAd = cached
            self.isFailed = false
            return
        }

        if let state = AdNativeCache.shared.state(for: targetKey), state == .failed {
            self.nativeAd = nil
            self.isFailed = true
            return
        }

        AdNativeCache.shared.loadAd(for: targetKey) { result in
            guard self.cacheKey == targetKey else { return }
            switch result {
            case .success(let ad):
                self.nativeAd = ad
                self.isFailed = false
            case .failure:
                self.nativeAd = nil
                self.isFailed = true
            }
        }
    }
}
