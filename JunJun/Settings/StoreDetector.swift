import Foundation
#if canImport(MarketplaceKit)
@preconcurrency import MarketplaceKit

@available(iOS 17.4, *)
extension AppDistributor: @unchecked @retroactive Sendable {}
#endif // canImport(MarketplaceKit)

/// Detects the installation source of the app (App Store, TestFlight, EU Alternative Marketplace, etc.)
enum StoreDetector {
    struct StoreInfo: Sendable, Equatable {
        let name: String
        let isAlternativeMarketplace: Bool
    }

    /// Store detection is supported on iOS and Simulator, but not on Mac Catalyst / iPad on Mac.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return !ProcessInfo.processInfo.isiOSAppOnMac && !ProcessInfo.processInfo.isMacCatalystApp
        #endif
    }

    /// Default placeholder name for UI ("Simulator" on simulator, "-" on iOS, nil when unsupported).
    static var defaultStoreName: String? {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        return isSupported ? "-" : nil
        #endif
    }

    /// Detects installation store info.
    static func detect() async -> StoreInfo {
        guard isSupported else {
            return StoreInfo(name: "App Store", isAlternativeMarketplace: false)
        }

        #if targetEnvironment(simulator)
        return StoreInfo(name: "Simulator", isAlternativeMarketplace: false)
        #elseif DEBUG
        return StoreInfo(name: "Xcode", isAlternativeMarketplace: false)
        #else
        #if canImport(MarketplaceKit)
        if #available(iOS 17.4, *) {
            if let info = await MarketplaceKitRunner.query() {
                return info
            }
        }
        #endif // canImport(MarketplaceKit)

        // MarketplaceKitで取得できない場合・エラー時のフォールバック (安全側に倒して App Store 扱い)
        return StoreInfo(name: "Unknown2", isAlternativeMarketplace: false)
        #endif
    }

    /// Checks whether the app was installed from an alternative marketplace (e.g. EU Alt Marketplace, Web).
    static func checkIsAlternativeMarketplace() async -> Bool {
        guard isSupported else { return false }
        return await detect().isAlternativeMarketplace
    }

    /// Fetches the store display name (e.g. "App Store", "TestFlight", "AltStore PAL").
    static func fetchStoreName() async -> String? {
        guard isSupported else { return nil }
        return await detect().name
    }
}

#if canImport(MarketplaceKit)
@available(iOS 17.4, *)
private enum MarketplaceKitRunner {
    /// Isolated query function to ensure `AppDistributor` metadata accessor is not called
    /// in the async frame prologue of `StoreDetector.detect()` when running on unsupported platforms (Mac/Catalyst).
    @inline(never)
    static func query() async -> StoreDetector.StoreInfo? {
        guard let distributor = try? await AppDistributor.current else {
            return nil
        }
        switch distributor {
        case .appStore:
            return StoreDetector.StoreInfo(name: "App Store", isAlternativeMarketplace: false)
        case .testFlight:
            return StoreDetector.StoreInfo(name: "TestFlight", isAlternativeMarketplace: false)
        case .marketplace(let name):
            let displayName = name.isEmpty ? "Alternative Marketplace" : name
            return StoreDetector.StoreInfo(name: displayName, isAlternativeMarketplace: true)
        case .web:
            return StoreDetector.StoreInfo(name: "Web", isAlternativeMarketplace: true)
        case .other:
            // App Review (審査環境) や AdHoc 等で .other になる場合があるため、
            // 審査時に課金をブロックしないよう isAlternativeMarketplace は false とする
            return StoreDetector.StoreInfo(name: "Other", isAlternativeMarketplace: false)
        @unknown default:
            return StoreDetector.StoreInfo(name: "Unknown1", isAlternativeMarketplace: false)
        }
    }
}
#endif
