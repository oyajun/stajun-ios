import Foundation
import StoreKit
import UIKit

/// Manages the total count of posts created on this device and triggers
/// App Store review requests at appropriate milestones.
/// Persisted in UserDefaults and intentionally survives logouts and account deletions.
enum PostCountStore {
    private static let postCountKey = "device_post_count"

    /// Total number of posts made on this device.
    static var count: Int {
        get { UserDefaults.standard.integer(forKey: postCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: postCountKey) }
    }

    /// Increments the post count by 1 and returns the updated count.
    @discardableResult
    static func increment() -> Int {
        let newCount = count + 1
        count = newCount
        return newCount
    }

    /// Checks and executes post completion milestones (4th post -> invite friends, 6th post -> app review).
    @MainActor
    static func handlePostCompleted(onInviteFriends: @escaping () -> Void) {
        let currentCount = count
        Task { @MainActor in
            // Delay slightly to ensure any presenting sheet (such as ComposePostView) has dismissed cleanly.
            try? await Task.sleep(for: .milliseconds(600))
            if currentCount == 4 {
                onInviteFriends()
            } else if currentCount == 6 {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: windowScene)
                }
            }
        }
    }
}
