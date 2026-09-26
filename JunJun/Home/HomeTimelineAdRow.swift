import SwiftUI

struct HomeTimelineAdRow: View {
    let slotIndex: Int
    let adRefreshID: UUID
    let scope: PostScope
    @Environment(AppState.self) private var appState

    var body: some View {
        if Config.showAds && !appState.isPro {
            VStack(spacing: 0) {
                switch TimelineAdSlotManager.shared.adType(for: slotIndex, scope: scope) {
                case .primeStudent:
                    PrimeStudentBannerView()
                        .frame(height: 250)
                case .helloTalk:
                    CustomPromotionBannerView(item: AffiliateCache.shared.helloTalkItem(for: "timeline-hellotalk-\(scope.rawValue)-\(slotIndex)-\(adRefreshID)"))
                        .frame(height: 250)
                case .comicJp:
                    CustomPromotionBannerView(item: Config.comicJpAdItem)
                        .frame(height: 250)
                case .teamLabBody:
                    CustomPromotionBannerView(item: Config.teamLabBodyProAdItem)
                        .frame(height: 250)
                case .adMobNative:
                    NativeAdCard(cacheKey: "timeline-admob-native-\(scope.rawValue)-\(slotIndex)-\(adRefreshID)")
                        .frame(height: 340)
                case .adMobBanner:
                    AdBannerCard(cacheKey: "timeline-admob-banner-\(scope.rawValue)-\(slotIndex)-\(adRefreshID)")
                        .frame(height: 250)
                case .affiliate:
                    AffiliateBannerCard(cacheKey: "timeline-affiliate-\(scope.rawValue)-\(slotIndex)-\(adRefreshID)")
                        .frame(height: 125)
                }
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}
