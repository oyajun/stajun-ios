import Foundation
#if canImport(MarketplaceKit)
@preconcurrency import MarketplaceKit

@available(iOS 17.4, *)
extension AppDistributor: @unchecked @retroactive Sendable {}
#endif

enum StoreDetector {
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
        return await MarketplaceKitRunner.fetch()
        #endif
    }
}

#if !targetEnvironment(simulator)
private enum MarketplaceKitRunner {
    nonisolated static func fetch() async -> String {
        #if canImport(MarketplaceKit)
        if #available(iOS 17.4, *) {
            do {
                let distributor = try await AppDistributor.current
                switch distributor {
                case .appStore:
                    return "App Store"
                case .testFlight:
                    return "TestFlight"
                case .marketplace(let name):
                    return name.isEmpty ? "Alternative Marketplace" : name
                case .web:
                    return "Web"
                case .other:
                    return "Other"
                @unknown default:
                    return "Unknown"
                }
            } catch {
                return "Unknown"
            }
        }
        #endif
        return "Unknown"
    }
}
#endif
