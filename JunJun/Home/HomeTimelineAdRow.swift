import SwiftUI

struct HomeTimelineAdRow: View {
    let index: Int
    let firstAdIndex: Int
    let adInterval: Int
    let adRefreshID: UUID

    var body: some View {
        let slotIndex = (index - firstAdIndex) / adInterval
        VStack(spacing: 0) {
            if Config.isJapanRegion {
                switch TimelineAdSlotManager.shared.adType(for: slotIndex) {
                case .primeStudent:
                    PrimeStudentBannerView()
                case .adMob:
                    AdBannerCard(cacheKey: "timeline-admob-\(index)-\(adRefreshID)")
                case .affiliate:
                    AffiliateBannerCard(cacheKey: "timeline-affiliate-\(index)-\(adRefreshID)")
                }
            } else {
                AdBannerCard(cacheKey: "timeline-admob-\(index)-\(adRefreshID)")
            }
            Divider()
                .padding(.horizontal, 16)
        }
        .id("ad-row-\(index)-\(adRefreshID)")
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}
