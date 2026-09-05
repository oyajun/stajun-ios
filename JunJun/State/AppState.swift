import Foundation
import SwiftUI
import UserNotifications

// MARK: - Auth State

enum AuthState: Equatable {
    case checking         // Verifying token on startup
    case unauthenticated  // User not logged in (shows Auth Flow)
    case authenticated    // Authenticated + onboarding complete
}

// MARK: - AppState

@Observable
final class AppState {
    var authState: AuthState = .checking
    var currentUser: UserProfile? {
        didSet {
            if let user = currentUser {
                if user.isPro == true {
                    self.isPro = true
                }
                if oldValue?.id != user.id {
                    Task { await SubscriptionManager.shared.identifyUser(id: user.id) }
                }
            }
        }
    }

    /// Whether the current user is a Pro subscriber
    var isPro: Bool = false

    /// Whether the user is currently studying — initialised from LocalStudyStore so
    /// the border overlay is correct immediately on launch before HomeView appears.
    var isStudying: Bool = LocalStudyStore.localStartedAt != nil

    /// Signed-in email, persisted in Keychain so it can be reused for re-authentication (e.g. account deletion)
    var userEmail: String? {
        didSet {
            KeychainHelper.email = userEmail
        }
    }
    
    /// True if the app has passed its hardcoded expiration date
    var requiresUpdate: Bool = false

    /// Unread notification count for tab badge
    var unreadNotificationCount: Int = 0

    /// Full User ID from deep link (junjun://u/[fulluserid]) to display
    var deepLinkedUserId: String?

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "junjun" else { return }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        // Handles junjun://u/[fulluserid] and junjun://users/[fulluserid]
        if url.host == "u" || url.host == "users", let userId = pathComponents.first, !userId.isEmpty {
            deepLinkedUserId = userId
        } else if pathComponents.count >= 2, (pathComponents[0] == "u" || pathComponents[0] == "users") {
            deepLinkedUserId = pathComponents[1]
        } else if let userId = pathComponents.first, !userId.isEmpty {
            deepLinkedUserId = userId
        }
    }

    init() {
        self.userEmail = KeychainHelper.email
        checkExpiration()
        setupNotificationObservers()
        setupSubscriptionObserver()
        Task { await checkExistingSession() }
    }

    private func setupSubscriptionObserver() {
        SubscriptionManager.shared.onProStatusChanged = { [weak self] isPro in
            Task { @MainActor in
                self?.isPro = isPro || (self?.currentUser?.isPro == true)
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .didTapPushNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let userId = note.userInfo?["userId"] as? String, !userId.isEmpty {
                self.deepLinkedUserId = userId
            }
            Task {
                await self.poll()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .didReceiveRemoteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.poll()
            }
        }
    }
    
    private func checkExpiration() {
        if let expirationDate = Config.expirationDate, Date() > expirationDate {
            requiresUpdate = true
        }
    }

    /// On startup: Verify token on server if it exists in Keychain
    private func checkExistingSession() async {
        guard KeychainHelper.token != nil else {
            authState = .unauthenticated
            return
        }

        // If we have a cached profile, enter the app immediately so launch isn't
        // blocked on the network, then verify the session in the background.
        if let cached = ProfileCache.load() {
            currentUser = cached
            authState = .authenticated
            NotificationHandler.syncPendingTokenIfNeeded()
            Task { await self.poll() }
        }

        do {
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            ProfileCache.save(profile)
            authState = .authenticated
            checkFollowingAndRequestPushPermission()
            NotificationHandler.syncPendingTokenIfNeeded()
            await poll()
        } catch APIError.unauthorized {
            // Token actually invalid → sign out
            KeychainHelper.token = nil
            ProfileCache.clear()
            currentUser = nil
            unreadNotificationCount = 0
            authState = .unauthenticated
        } catch {
            // Server unreachable / network error / server error:
            // a token exists but we can't verify it right now. Keep the user
            // signed in (optimistically) instead of logging them out just
            // because the server is down. Use the cached profile if we have one.
            currentUser = ProfileCache.load()
            authState = .authenticated
            checkFollowingAndRequestPushPermission()
            NotificationHandler.syncPendingTokenIfNeeded()
        }
    }

    // MARK: - Polling & Notifications

    /// Polling: fetches unread notifications count, latest following presence, etc.
    func poll(force: Bool = false) async {
        guard authState == .authenticated else { return }
        do {
            let res = try await APIClient.poll(force: force)
            unreadNotificationCount = res.unreadCount
            FeedCache.save(res.users)
        } catch {
            #if DEBUG
            print("[Polling] Failed: \(error)")
            #endif
        }
    }

    /// Mark all notifications as read and reset badge count
    func markAllNotificationsAsRead() async {
        unreadNotificationCount = 0
        do {
            try await APIClient.markAllNotificationsAsRead()
        } catch {
            #if DEBUG
            print("[Notifications] Failed to mark notifications as read: \(error)")
            #endif
        }
    }

    // MARK: - Auth Actions

    /// Send OTP for initial login, email registration, email change, or account deletion
    func sendOTP(email: String, mode: AuthFlowMode) async throws {
        switch mode {
        case .login, .deleteAccount:
            try await APIClient.sendOTP(email: email)
        case .registerEmail, .changeEmail:
            try await APIClient.requestEmailChange(newEmail: email)
        }
    }

    /// Verify OTP code and handle state updates per mode
    func verifyOTP(email: String, otp: String, mode: AuthFlowMode) async throws {
        switch mode {
        case .login:
            try await APIClient.signIn(email: email, otp: otp)
            userEmail = email
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            authState = .authenticated
            checkFollowingAndRequestPushPermission()
            NotificationHandler.syncPendingTokenIfNeeded()
            await poll()

        case .registerEmail, .changeEmail:
            try await APIClient.changeEmail(newEmail: email, otp: otp)
            userEmail = email
            let profile = try await APIClient.getMyProfile()
            updateCurrentUser(profile)
            authState = .authenticated

        case .deleteAccount:
            try await APIClient.signIn(email: email, otp: otp)
            try await APIClient.deleteAccount()
            clearAfterAccountDeletion()
        }
    }

    /// Resend OTP code
    func resendOTP(email: String, mode: AuthFlowMode) async throws {
        try await sendOTP(email: email, mode: mode)
    }

    /// Complete onboarding
    func completeOnboarding(profile: UserProfile) {
        currentUser = profile
        ProfileCache.save(profile)
        authState = .authenticated
        NotificationHandler.syncPendingTokenIfNeeded()
        Task { await poll() }
    }

    /// Create an anonymous profile
    func createAnonymousProfile(name: String, iconEmoji: String, iconBackgroundColor: String) async throws {
        try await APIClient.signInAnonymous()
        let profile = try await APIClient.updateProfile(name: name, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        userEmail = nil
        completeOnboarding(profile: profile)
    }

    /// Update profile
    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
        if let email = profile.email {
            userEmail = email
        }
        ProfileCache.save(profile)
    }

    /// Sign out
    func signOut() async {
        try? await APIClient.signOut()
        KeychainHelper.token = nil
        NotificationHandler.resetRegisteredToken()
        LocalStudyStore.clear()
        FeedCache.clear()
        ProfileCache.clear()
        PostsCache.clear()
        StatsCache.clear()
        UserProfileCache.clear()
        NotificationsCache.clear()
        await APIClient.clearPollingCache()
        currentUser = nil
        isStudying = false
        authState = .unauthenticated
        await SubscriptionManager.shared.resetUser()
    }

    /// Clean up after account deletion
    func clearAfterAccountDeletion() {
        KeychainHelper.token = nil
        userEmail = nil
        NotificationHandler.resetRegisteredToken()
        LocalStudyStore.clear()
        FeedCache.clear()
        ProfileCache.clear()
        PostsCache.clear()
        StatsCache.clear()
        UserProfileCache.clear()
        NotificationsCache.clear()
        Task { await APIClient.clearPollingCache() }
        currentUser = nil
        isStudying = false
        authState = .unauthenticated
        Task { await SubscriptionManager.shared.resetUser() }
    }

    // MARK: - Push Notifications

    /// Prompts for push notification permissions if not determined yet.
    /// Used when following a user or logging in while already following users.
    func requestPushPermissionIfAppropriate() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                return
            }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } catch {
                #if DEBUG
                print("[Push Notifications] Authorization error: \(error)")
                #endif
            }
        }
    }

    /// Check if current user is following anyone; if so, request push notification permission
    func checkFollowingAndRequestPushPermission() {
        Task {
            do {
                let following = try await APIClient.getFollowing(userId: "me")
                if !following.users.isEmpty {
                    requestPushPermissionIfAppropriate()
                }
            } catch {
                #if DEBUG
                print("[Push Notifications] Failed to fetch following for permission check: \(error)")
                #endif
            }
        }
    }
}
