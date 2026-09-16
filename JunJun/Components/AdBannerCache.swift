import GoogleMobileAds
import Foundation

enum BannerAdState: Sendable {
    case loading
    case success
    case failed
}

/// Keeps loaded GADBannerView instances alive by key so they are not
/// reloaded when List rows are recycled during scrolling.
@MainActor
final class AdBannerCache {
    static let shared = AdBannerCache()
    private var cache: [String: (view: GADBannerView, state: BannerAdState)] = [:]
    private init() {}

    /// Returns an existing banner view for the given key, or creates and
    /// stores a new one. If previous attempt failed, a fresh banner is created to allow retry.
    func banner(for key: String, adUnitID: String, adSize: GADAdSize) -> (view: GADBannerView, isNew: Bool, state: BannerAdState) {
        if let existing = cache[key] {
            if existing.state != .failed {
                return (existing.view, false, existing.state)
            }
            // If it failed previously, remove and retry fresh
            existing.view.removeFromSuperview()
            existing.view.delegate = nil
            cache.removeValue(forKey: key)
        }
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        cache[key] = (bannerView, .loading)
        return (bannerView, true, .loading)
    }

    func markLoaded(for key: String) {
        if let existing = cache[key] {
            cache[key] = (existing.view, .success)
        }
    }

    func markFailed(for key: String) {
        if let existing = cache[key] {
            cache[key] = (existing.view, .failed)
        }
    }

    func state(for key: String) -> BannerAdState? {
        cache[key]?.state
    }

    /// Discards all cached banner views so fresh ads will be requested.
    func clearCache() {
        for item in cache.values {
            item.view.removeFromSuperview()
            item.view.delegate = nil
        }
        cache.removeAll()
    }
}
