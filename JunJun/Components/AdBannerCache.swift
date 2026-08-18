import GoogleMobileAds

/// Keeps loaded GADBannerView instances alive by key so they are not
/// reloaded when List rows are recycled during scrolling.
final class AdBannerCache {
    static let shared = AdBannerCache()
    private var cache: [String: GADBannerView] = [:]
    private init() {}

    /// Returns an existing banner view for the given key, or creates and
    /// stores a new one. The `isNew` flag indicates whether a `load()` call
    /// is still needed.
    func banner(for key: String, adUnitID: String, adSize: GADAdSize) -> (view: GADBannerView, isNew: Bool) {
        if let existing = cache[key] {
            return (existing, false)
        }
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        cache[key] = bannerView
        return (bannerView, true)
    }
}
