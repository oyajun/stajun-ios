import Foundation
import GoogleMobileAds

enum NativeAdState: Sendable {
    case loading
    case success
    case failed
}

@MainActor
final class AdNativeCache: NSObject, GADNativeAdLoaderDelegate {
    static let shared = AdNativeCache()
    
    private var nativeAds: [String: GADNativeAd] = [:]
    private var states: [String: NativeAdState] = [:]
    private var loaders: [String: GADAdLoader] = [:]
    private var completionHandlers: [String: [(Result<GADNativeAd, Error>) -> Void]] = [:]

    private override init() {
        super.init()
    }

    /// Returns the cached GADNativeAd if loaded, or starts loading if not yet loaded.
    func loadAd(
        for key: String,
        completion: @escaping (Result<GADNativeAd, Error>) -> Void
    ) {
        loadAd(for: key, adUnitID: Config.adMobNativeUnitID, completion: completion)
    }

    /// Returns the cached GADNativeAd if loaded with specific adUnitID, or starts loading if not yet loaded.
    func loadAd(
        for key: String,
        adUnitID: String,
        completion: @escaping (Result<GADNativeAd, Error>) -> Void
    ) {
        if let ad = nativeAds[key] {
            completion(.success(ad))
            return
        }

        if states[key] == .loading {
            completionHandlers[key, default: []].append(completion)
            return
        }

        states[key] = .loading
        completionHandlers[key] = [completion]

        let videoOptions = GADVideoOptions()
        videoOptions.startMuted = true

        let nativeOptions = GADNativeAdViewAdOptions()
        nativeOptions.preferredAdChoicesPosition = .topRightCorner

        let multipleOptions = GADMultipleAdsAdLoaderOptions()
        multipleOptions.numberOfAds = 1

        let rootVC = AdBannerView.Coordinator.findRootViewController()

        let adLoader = GADAdLoader(
            adUnitID: adUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: [videoOptions, nativeOptions, multipleOptions]
        )
        adLoader.delegate = self
        loaders[key] = adLoader

        let request = GADRequest()
        if !Config.adMobKeywords.isEmpty {
            request.keywords = Config.adMobKeywords
        }
        adLoader.load(request)
    }

    func state(for key: String) -> NativeAdState? {
        states[key]
    }

    func ad(for key: String) -> GADNativeAd? {
        nativeAds[key]
    }

    func clearCache() {
        nativeAds.removeAll()
        states.removeAll()
        loaders.removeAll()
        completionHandlers.removeAll()
    }

    // MARK: - GADNativeAdLoaderDelegate

    nonisolated func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        Task { @MainActor in
            guard let (key, _) = self.loaders.first(where: { $0.value === adLoader }) else { return }
            self.nativeAds[key] = nativeAd
            self.states[key] = .success
            let handlers = self.completionHandlers.removeValue(forKey: key) ?? []
            for handler in handlers {
                handler(.success(nativeAd))
            }
        }
    }

    nonisolated func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            guard let (key, _) = self.loaders.first(where: { $0.value === adLoader }) else { return }
            #if DEBUG
            print("[AdMob Native] Failed to receive ad for key \(key): \(error.localizedDescription)")
            #endif
            self.states[key] = .failed
            let handlers = self.completionHandlers.removeValue(forKey: key) ?? []
            for handler in handlers {
                handler(.failure(error))
            }
        }
    }
}
