import Foundation
import SwiftUI
import RevenueCat
import StoreKit

@Observable
@MainActor
final class SubscriptionManager: NSObject, PurchasesDelegate {
    static let shared = SubscriptionManager()

    /// Whether the user currently has an active Pro subscription
    var isPro: Bool = false
    
    /// Expiration date of the Pro subscription if available
    var proExpiresAt: Date?

    /// Callback when pro status updates to notify external observers (e.g. AppState)
    var onProStatusChanged: ((Bool) -> Void)?

    /// Monthly package fetched from RevenueCat
    var proPackage: Package?

    /// Whether the app was installed from an alternative marketplace (or IAP is unavailable)
    var isAlternativeMarketplace: Bool = false

    /// Loading state for network requests (offerings / initial fetch)
    var isLoading: Bool = false

    /// Purchasing in progress
    var isPurchasing: Bool = false

    /// Restoring in progress
    var isRestoring: Bool = false

    /// Flag to trigger paywall modal presentation from anywhere
    var showPaywall: Bool = false

    /// Error message for UI feedback
    var errorMessage: String?

    /// Localized monthly price string (e.g., "¥300 / 月")
    var localizedPriceString: String {
        if let pkg = proPackage {
            return pkg.localizedPriceString
        }
        return Config.proMonthlyFallbackPrice
    }

    override private init() {
        super.init()
    }

    /// Initialize RevenueCat SDK. Called on app launch.
    func initialize() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        let initialUserId = ProfileCache.load()?.id
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey, appUserID: initialUserId)
        Purchases.shared.delegate = self

        Task {
            await checkMarketplaceStatus()
            await fetchOfferings()
            await checkCustomerInfo()
        }
    }

    /// Checks if the app was installed from an alternative app marketplace or if StoreKit payments are unavailable
    func checkMarketplaceStatus() async {
        #if DEBUG
        isAlternativeMarketplace = false
        return
        #else
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                if transaction.environment == .sandbox || transaction.environment == .xcode || transaction.environment == .production {
                    isAlternativeMarketplace = false
                }
            case .unverified:
                isAlternativeMarketplace = true
            }
        } catch {
            // AppTransaction is not available in local developer installs; do not block testing
            isAlternativeMarketplace = false
        }
        #endif
    }

    /// Link RevenueCat with JunJun user ID
    func identifyUser(id: String) async {
        guard Purchases.shared.appUserID != id else {
            await checkCustomerInfo()
            return
        }
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(id)
            updateProStatus(from: customerInfo)
            await syncWithServer()
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Failed to identify user: \(error)")
            #endif
            await checkCustomerInfo()
        }
    }

    /// Reset user on sign out
    func resetUser() async {
        do {
            _ = try await Purchases.shared.logOut()
            isPro = false
            proExpiresAt = nil
            onProStatusChanged?(false)
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Failed to log out user: \(error)")
            #endif
        }
    }

    /// Fetch available offerings from RevenueCat
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                self.proPackage = current.monthly ?? current.availablePackages.first
            } else if let defaultOffering = offerings.offering(identifier: "default") {
                self.proPackage = defaultOffering.monthly ?? defaultOffering.availablePackages.first
            }
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Failed to fetch offerings: \(error)")
            #endif
        }
    }

    /// Check customer info & active entitlements
    func checkCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateProStatus(from: customerInfo)
            await syncWithServer()
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Failed to fetch customer info: \(error)")
            #endif
        }
    }

    /// Purchase the Pro package
    func purchasePro() async -> Bool {
        guard let package = proPackage else {
            errorMessage = String(localized: "Product not available. Please try again later.")
            return false
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let purchaseResult = try await Purchases.shared.purchase(package: package)
            if !purchaseResult.userCancelled {
                updateProStatus(from: purchaseResult.customerInfo)
                await syncWithServer()
                return isPro
            }
            return false
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Purchase error: \(error)")
            #endif
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async -> Bool {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateProStatus(from: customerInfo)
            await syncWithServer()
            return isPro
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Restore error: \(error)")
            #endif
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Sync active Pro status with backend server
    func syncWithServer() async {
        do {
            _ = try await APIClient.syncProStatus(isPro: isPro, proExpiresAt: proExpiresAt)
        } catch {
            #if DEBUG
            print("[SubscriptionManager] Failed to sync Pro status with server: \(error)")
            #endif
        }
    }

    /// Updates internal isPro state from RevenueCat CustomerInfo
    private func updateProStatus(from customerInfo: CustomerInfo) {
        if let entitlement = customerInfo.entitlements[Config.proEntitlementID], entitlement.isActive {
            isPro = true
            proExpiresAt = entitlement.expirationDate
        } else {
            isPro = false
            proExpiresAt = nil
        }

        #if DEBUG
        print("[SubscriptionManager] updateProStatus: isPro=\(isPro), expiresAt=\(String(describing: proExpiresAt))")
        #endif

        onProStatusChanged?(isPro)
    }

    // MARK: - PurchasesDelegate

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateProStatus(from: customerInfo)
            await self.syncWithServer()
        }
    }
}
