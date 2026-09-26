import SwiftUI
import GoogleMobileAds

/// タイムライン用のネイティブ広告カード
/// UIレイアウト（アイコン、タイトル、PR表記、Adバッジ、×ボタン）を SwiftUI で構築し、
/// メディア（画像/動画）とCTAボタンを AdMob の GADNativeAdView とバインドして表示。
/// GADNativeAdView がメディア領域から始まるため、AdMob の AdChoices（iボタン）は画像/動画の右上に配置されます。
struct NativeAdCard: View {
    let cacheKey: String
    @Environment(AppState.self) private var appState
    @State private var nativeAd: GADNativeAd?
    @State private var isFailed: Bool = false

    init(cacheKey: String) {
        self.cacheKey = cacheKey
        if let cached = AdNativeCache.shared.ad(for: cacheKey) {
            _nativeAd = State(initialValue: cached)
        } else if let state = AdNativeCache.shared.state(for: cacheKey), state == .failed {
            _isFailed = State(initialValue: true)
        }
    }

    var body: some View {
        if Config.showAds && !appState.isPro {
            Group {
                if isFailed {
                    // ネイティブ広告が取得できなかった場合は、従来の AdMob バナーへフォールバック（340pt の中央に固定配置）
                    AdBannerCard(cacheKey: "banner-fallback-\(cacheKey)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let ad = nativeAd {
                    NativeAdContentView(nativeAd: ad)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    // ロード中プレースホルダー（チラつき・高さ変動防止）
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            loadNativeAd()
                        }
                }
            }
            .frame(height: 340)
            .clipped()
        }
    }

    private func loadNativeAd() {
        if let cached = AdNativeCache.shared.ad(for: cacheKey) {
            self.nativeAd = cached
            return
        }

        if let state = AdNativeCache.shared.state(for: cacheKey), state == .failed {
            self.isFailed = true
            return
        }

        AdNativeCache.shared.loadAd(for: cacheKey) { result in
            switch result {
            case .success(let ad):
                self.nativeAd = ad
                self.isFailed = false
            case .failure:
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
