import SwiftUI

struct HomeTimelineAdRow: View {
    let slotIndex: Int
    let adRefreshID: UUID
    @Environment(AppState.self) private var appState

    var body: some View {
        if Config.showAds && !appState.isPro {
            VStack(spacing: 0) {
                switch TimelineAdSlotManager.shared.adType(for: slotIndex) {
                case .primeStudent:
                    PrimeStudentBannerView()
                        .frame(height: 250)
                case .helloTalk:
                    CustomPromotionBannerView(item: AffiliateCache.shared.helloTalkItem(for: "timeline-hellotalk-\(slotIndex)-\(adRefreshID)"))
                        .frame(height: 250)
                case .comicJp:
                    CustomPromotionBannerView(item: Config.comicJpAdItem)
                        .frame(height: 250)
                case .teamLabBody:
                    CustomPromotionBannerView(item: Config.teamLabBodyProAdItem)
                        .frame(height: 250)
                case .adMob:
                    NativeAdCard(cacheKey: "timeline-admob-\(slotIndex)-\(adRefreshID)")
                        .frame(height: 340)
                case .affiliate:
                    AffiliateBannerCard(cacheKey: "timeline-affiliate-\(slotIndex)-\(adRefreshID)")
                        .frame(height: 125)
                }
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}
