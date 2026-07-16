import Foundation
import SwiftUI

// MARK: - Auth State

enum AuthState: Equatable {
    case checking              // Verifying token on startup
    case unauthenticated       // Unauthenticated (SC-01)
    case awaitingOTP(email: String) // Waiting for OTP input (SC-02)
    case onboarding            // Authenticated but profile not registered (SC-03)
    case authenticated         // Authenticated + onboarding complete
}

// MARK: - AppState

@Observable
final class AppState {
    var authState: AuthState = .checking
    var currentUser: UserProfile?

    /// Signed-in email, persisted in Keychain so it can be reused for re-authentication (e.g. account deletion)
    var userEmail: String? {
        get { KeychainHelper.email }
        set { KeychainHelper.email = newValue }
    }

    init() {
        Task { await checkExistingSession() }
    }

    /// On startup: Verify token on server if it exists in Keychain
    private func checkExistingSession() async {
        guard KeychainHelper.token != nil else {
            authState = .unauthenticated
            return
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
            authState = .unauthenticated
        } catch APIError.onboardingRequired {
            authState = .onboarding
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
        do {
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            authState = .authenticated
        } catch APIError.onboardingRequired {
            authState = .onboarding
        }
    }

    /// Complete onboarding
    func completeOnboarding(profile: UserProfile) {
        currentUser = profile
        ProfileCache.save(profile)
        authState = .authenticated
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
        authState = .unauthenticated
    }

    /// Clean up after account deletion
    func clearAfterAccountDeletion() {
        KeychainHelper.token = nil
        KeychainHelper.email = nil
        FeedCache.clear()
        ProfileCache.clear()
        currentUser = nil
        authState = .unauthenticated
    }
}
