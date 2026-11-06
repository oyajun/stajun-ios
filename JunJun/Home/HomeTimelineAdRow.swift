import SwiftUI

struct HomeTimelineAdRow: View {
    let slotIndex: Int
    let adRefreshID: UUID
    let scope: PostScope
    @Environment(AppState.self) private var appState

    var body: some View {
        if Config.showAds && !appState.isPro {
            let rowKey = "\(scope.rawValue)-\(slotIndex)-\(adRefreshID.uuidString)"
            VStack(spacing: 0) {
                switch TimelineAdSlotManager.shared.adType(for: slotIndex, scope: scope) {
                case .primeStudent:
                    PrimeStudentBannerView()
                        .id("prime-\(rowKey)")
                        .frame(height: 250)
                case .qoo10:
                    CustomPromotionBannerView(item: Config.qoo10AdItem)
                        .id("qoo10-\(rowKey)")
                        .frame(height: 250)
                case .shein:
                    CustomPromotionBannerView(item: Config.sheinAdItem)
                        .id("shein-\(rowKey)")
                        .frame(height: 250)
                case .comicJp:
                    CustomPromotionBannerView(item: Config.comicJpAdItem)
                        .id("comicjp-\(rowKey)")
                        .frame(height: 250)
                case .adMobNative:
                    let nativeKey = "timeline-admob-native-\(rowKey)"
                    NativeAdCard(cacheKey: nativeKey)
                        .id(nativeKey)
                        .frame(height: 340)
                case .adMobBanner:
                    let bannerKey = "timeline-admob-banner-\(rowKey)"
                    AdBannerCard(cacheKey: bannerKey)
                        .id(bannerKey)
                        .frame(height: 250)
                case .affiliate:
                    let affiliateKey = "timeline-affiliate-\(rowKey)"
                    AffiliateBannerCard(cacheKey: affiliateKey)
                        .id(affiliateKey)
                        .frame(height: 125)
                }
                Divider()
                    .padding(.horizontal, 16)
            }
            .id("ad-row-\(rowKey)")
        }
    }
}
