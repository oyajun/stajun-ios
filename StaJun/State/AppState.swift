import Foundation
import SwiftUI

// MARK: - Auth State

enum AuthState: Equatable {
    case checking              // Verifying token on startup
    case welcome               // Shows the new welcome view
    case emailLogin            // Email input for existing users
    case awaitingOTP(email: String) // Waiting for OTP input (SC-02)
    case anonymousOnboarding   // Profile setup for new anonymous user
    case authenticated         // Authenticated + onboarding complete
}

// MARK: - AppState

@Observable
final class AppState {
    var authState: AuthState = .checking
    var currentUser: UserProfile?

    /// Whether the user is currently studying — initialised from LocalStudyStore so
    /// the border overlay is correct immediately on launch before HomeView appears.
    var isStudying: Bool = LocalStudyStore.localStartedAt != nil

    /// Signed-in email, persisted in Keychain so it can be reused for re-authentication (e.g. account deletion)
    var userEmail: String? {
        didSet {
            KeychainHelper.email = userEmail
        }
    }

    init() {
        self.userEmail = KeychainHelper.email
        Task { await checkExistingSession() }
    }

    /// On startup: Verify token on server if it exists in Keychain
    private func checkExistingSession() async {
        guard KeychainHelper.token != nil else {
            authState = .welcome
            return
        }

        // If we have a cached profile, enter the app immediately so launch isn't
        // blocked on the network, then verify the session in the background.
        if let cached = ProfileCache.load() {
            currentUser = cached
            authState = .authenticated
        }

        do {
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            ProfileCache.save(profile)
            authState = .authenticated
        } catch APIError.unauthorized {
            // Token actually invalid → sign out
            KeychainHelper.token = nil
            ProfileCache.clear()
            currentUser = nil
            authState = .welcome
        } catch {
            // Server unreachable / network error / server error:
            // a token exists but we can't verify it right now. Keep the user
            // signed in (optimistically) instead of logging them out just
            // because the server is down. Use the cached profile if we have one.
            currentUser = ProfileCache.load()
            authState = .authenticated
        }
    }

    // MARK: - Actions

    /// Send OTP after email input and transition to awaitingOTP
    func requestOTP(email: String) async throws {
        try await APIClient.sendOTP(email: email)
        authState = .awaitingOTP(email: email)
    }

    /// Verify OTP and check profile state after successful sign-in
    func verifyOTP(email: String, otp: String) async throws {
        try await APIClient.signIn(email: email, otp: otp)
        // Token already saved to Keychain in signIn
        userEmail = email
        let profile = try await APIClient.getMyProfile()
        currentUser = profile
        authState = .authenticated
    }

    /// Complete onboarding
    func completeOnboarding(profile: UserProfile) {
        currentUser = profile
        ProfileCache.save(profile)
        authState = .authenticated
    }

    /// Create an anonymous profile
    func createAnonymousProfile(name: String, iconEmoji: String, iconBackgroundColor: String) async throws {
        try await APIClient.signInAnonymous()
        let profile = try await APIClient.updateProfile(name: name, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        completeOnboarding(profile: profile)
    }

    /// Update profile
    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
        ProfileCache.save(profile)
    }

    /// Sign out
    func signOut() async {
        try? await APIClient.signOut()
        KeychainHelper.token = nil
        FeedCache.clear()
        ProfileCache.clear()
        currentUser = nil
        isStudying = false
        authState = .welcome
    }

    /// Clean up after account deletion
    func clearAfterAccountDeletion() {
        KeychainHelper.token = nil
        userEmail = nil
        FeedCache.clear()
        ProfileCache.clear()
        currentUser = nil
        isStudying = false
        authState = .welcome
    }
}
