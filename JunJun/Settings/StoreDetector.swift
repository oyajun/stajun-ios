import Foundation
#if canImport(MarketplaceKit)
@preconcurrency import MarketplaceKit

@available(iOS 17.4, *)
extension AppDistributor: @unchecked @retroactive Sendable {}
#endif

enum StoreDetector {
    struct StoreInfo: Sendable, Equatable {
        let name: String
        let isAlternativeMarketplace: Bool
    }

    /// Returns true if Store info is supported on this platform/environment.
    /// Returns false on macOS (Designed for iPad / Mac Catalyst).
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp {
            return false
        }
        return true
        #endif
    }

    /// Immediate default store name: "Simulator" for simulator, "-" for supported iOS, or nil for macOS.
    static var defaultStoreName: String? {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        return isSupported ? "-" : nil
        #endif
    }

    /// Fetches the store name asynchronously.
    static func fetchStoreName() async -> String? {
        guard isSupported else { return nil }

        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        return await detectStoreInfo().name
        #endif
    }

    /// Determines whether the app is installed from an alternative app marketplace (AltStore, Web, Other distribution)
    static func checkIsAlternativeMarketplace() async -> Bool {
        guard isSupported else { return false }

        #if targetEnvironment(simulator)
        return false
        #else
        return await detectStoreInfo().isAlternativeMarketplace
        #endif
    }

    /// Fetches full store info asynchronously.
    static func fetchStoreInfo() async -> StoreInfo? {
        guard isSupported else { return nil }

        #if targetEnvironment(simulator)
        return StoreInfo(name: "Simulator", isAlternativeMarketplace: false)
        #else
        return await detectStoreInfo()
        #endif
    }

    #if !targetEnvironment(simulator)
    private static func detectStoreInfo() async -> StoreInfo {
        #if DEBUG
        // When running in Debug mode from Xcode, always treat as Xcode development
        return StoreInfo(name: "Xcode", isAlternativeMarketplace: false)
        #else
        let provisionURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
        let receiptURL = Bundle.main.appStoreReceiptURL
        let receiptExists = receiptURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

        // 1. Check if it's an official App Store production installation
        // App Store strips embedded.mobileprovision and provides a production receipt
        if provisionURL == nil && receiptExists && receiptURL?.lastPathComponent == "receipt" {
            return StoreInfo(name: "App Store", isAlternativeMarketplace: false)
        }

        // 2. Check embedded provisioning profile if present
        if let provisionURL = provisionURL,
           let provisionData = try? Data(contentsOf: provisionURL),
           let provisionString = String(data: provisionData, encoding: .isoLatin1) {
            // TestFlight
            if provisionString.contains("<key>beta-reports-active</key>") ||
               (receiptExists && receiptURL?.lastPathComponent == "sandboxReceipt") {
                return StoreInfo(name: "TestFlight", isAlternativeMarketplace: false)
            }

            // Explicit AltStore in provisioning profile (sideloaded via AltStore/AltServer)
            if provisionString.localizedCaseInsensitiveContains("AltStore") {
                return StoreInfo(name: "AltStore", isAlternativeMarketplace: true)
            }
        }

        // 3. Query MarketplaceKit for EU Alternative Marketplaces (e.g. AltStore PAL, Epic, Web)
        #if canImport(MarketplaceKit)
        if #available(iOS 17.4, *) {
            do {
                let distributor = try await AppDistributor.current
                switch distributor {
                case .appStore:
                    return StoreInfo(name: "App Store", isAlternativeMarketplace: false)
                case .testFlight:
                    return StoreInfo(name: "TestFlight", isAlternativeMarketplace: false)
                case .marketplace(let name):
                    let displayName = name.isEmpty ? "Alternative Marketplace" : name
                    return StoreInfo(name: displayName, isAlternativeMarketplace: true)
                case .web:
                    return StoreInfo(name: "Web", isAlternativeMarketplace: true)
                case .other:
                    return StoreInfo(name: "Other", isAlternativeMarketplace: true)
                @unknown default:
                    break
                }
            } catch {
                // If AppDistributor throws, continue to fallback
            }
        }
        #endif

        // 4. Fallback: If provision profile exists without App Store receipt in Release build, it's sideloaded
        if provisionURL != nil && !receiptExists {
            return StoreInfo(name: "Other", isAlternativeMarketplace: true)
        }

        return StoreInfo(name: "App Store", isAlternativeMarketplace: false)
        #endif
    }
    #endif
}
