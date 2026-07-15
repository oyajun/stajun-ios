import Foundation
import SwiftUI

// MARK: - Auth State

enum AuthState: Equatable {
    case checking              // 起動時にトークンを検証中
    case unauthenticated       // 未認証（SC-01）
    case awaitingOTP(email: String) // OTP 入力待ち（SC-02）
    case onboarding            // 認証済みだがプロフィール未登録（SC-03）
    case authenticated         // 認証＋オンボーディング完了
}

// MARK: - AppState

@Observable
final class AppState {
    var authState: AuthState = .checking
    var currentUser: UserProfile?

    init() {
        Task { await checkExistingSession() }
    }

    /// 起動時: Keychain にトークンがあればサーバーで検証する
    private func checkExistingSession() async {
        guard KeychainHelper.token != nil else {
            authState = .unauthenticated
            return
        }
        do {
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            authState = .authenticated
        } catch APIError.unauthorized {
            KeychainHelper.token = nil
            authState = .unauthenticated
        } catch APIError.onboardingRequired {
            authState = .onboarding
        } catch {
            // ネットワーク障害等 → 一旦未認証に
            KeychainHelper.token = nil
            authState = .unauthenticated
        }
    }

    // MARK: - Actions

    /// メール入力後、OTP 送信して awaitingOTP に遷移
    func requestOTP(email: String) async throws {
        try await APIClient.sendOTP(email: email)
        authState = .awaitingOTP(email: email)
    }

    /// OTP 検証→サインイン成功後、プロフィール状態を確認して遷移
    func verifyOTP(email: String, otp: String) async throws {
        try await APIClient.signIn(email: email, otp: otp)
        // signIn 内で Keychain にトークン保存済み
        do {
            let profile = try await APIClient.getMyProfile()
            currentUser = profile
            authState = .authenticated
        } catch APIError.onboardingRequired {
            authState = .onboarding
        }
    }

    /// オンボーディング完了
    func completeOnboarding(profile: UserProfile) {
        currentUser = profile
        authState = .authenticated
    }

    /// プロフィール更新
    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
    }

    /// ログアウト
    func signOut() async {
        try? await APIClient.signOut()
        KeychainHelper.token = nil
        currentUser = nil
        authState = .unauthenticated
    }

    /// アカウント削除後のクリーンアップ
    func clearAfterAccountDeletion() {
        KeychainHelper.token = nil
        currentUser = nil
        authState = .unauthenticated
    }
}
