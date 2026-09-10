import Foundation
import UIKit
import UserNotifications

final class NotificationHandler: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // アプリ起動時にリモート通知登録を要求（権限がある場合は最新トークンが発行される）
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    /// OS から受信した最新の APNs トークン（メモリ保持のみ・永続キャッシュなし）
    private(set) static var currentDeviceToken: String?

    /// トークン登録の排他制御用（現在進行中の Task）
    private static var activeRegistrationTask: Task<Void, Never>?

    /// 登録タスクのリセット（ログアウト時やアカウント削除時に呼び出し）
    static func resetRegisteredToken() {
        activeRegistrationTask?.cancel()
        activeRegistrationTask = nil
    }

    /// トークンをサーバーへ登録・上書きする独立関数。
    /// - Parameter token: 指定トークン（nil の場合は保持している currentDeviceToken を使用）
    /// - トークンなし、または未ログインの場合は安全にスルー（エラーを投げない）
    /// - キャッシュはせず、呼ばれたら確実に最新トークンをサーバーへ上書き同期
    @discardableResult
    static func setDeviceToken(_ token: String? = nil) async -> Bool {
        let tokenToSend = (token ?? currentDeviceToken)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // トークンなし、または未ログイン時は安全にスルー
        guard let tokenToSend = tokenToSend, !tokenToSend.isEmpty, KeychainHelper.token != nil else {
            #if DEBUG
            print("[APNs] setDeviceToken: Skipped (no token or user unauthenticated)")
            #endif
            return false
        }

        // 現在実行中のタスクがあればそれを待機して多重実行を防止
        if let existingTask = activeRegistrationTask {
            await existingTask.value
            return true
        }

        let task = Task {
            do {
                try await APIClient.registerAPNsToken(token: tokenToSend)
                #if DEBUG
                print("[APNs] Device token successfully set on server.")
                #endif
            } catch {
                #if DEBUG
                print("[APNs] Failed to set device token on server: \(error)")
                #endif
            }
        }

        activeRegistrationTask = task
        await task.value
        activeRegistrationTask = nil
        return true
    }

    /// ログイン完了時などに、未送信トークンがあればサーバーへ同期する（後方互換性用）
    static func syncPendingTokenIfNeeded() {
        Task {
            await setDeviceToken()
        }
    }

    enum RegistrationError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(localized: "Push notifications are turned off in your device settings. To receive notifications, please allow notifications for JunJun in Settings.")
            }
        }
    }

    /// プッシュ通知の強制再登録処理
    static func reregister() async throws {
        // 1. 通知の権限状態を確認・リクエスト
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                throw RegistrationError.permissionDenied
            }
        } else if settings.authorizationStatus == .denied {
            throw RegistrationError.permissionDenied
        }

        // 2. APNs リモート通知の登録を OS に要求
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // 3. 既に保持しているトークンがあれば直ちにサーバーへ送信
        if let token = currentDeviceToken, !token.isEmpty, KeychainHelper.token != nil {
            try await APIClient.registerAPNsToken(token: token)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // バックグラウンド移行時の処理（必要に応じて将来拡張）
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // フォアグラウンド復帰時にリモート通知登録をリクエストしてトークン変更を検知
        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Self.currentDeviceToken = token

        // トークン取得時に即時サーバーへ上書き送信
        Task {
            await Self.setDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[APNs] Failed to register for remote notifications: \(error)")
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Display notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .didReceiveRemoteNotification,
                object: nil
            )
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // 1. notificationId があればサーバー上で既読化
        if let notificationId = userInfo["notificationId"] as? String, !notificationId.isEmpty {
            Task {
                try? await APIClient.markNotificationAsRead(id: notificationId)
            }
        }

        // 2. フォロー通知なら該当ユーザーのプロフィールを開くよう通知
        if let type = userInfo["type"] as? String, type == "FOLLOW",
           let actorId = userInfo["actorId"] as? String, !actorId.isEmpty {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .didTapPushNotification,
                    object: nil,
                    userInfo: ["userId": actorId]
                )
            }
        } else {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .didTapPushNotification,
                    object: nil,
                    userInfo: [:]
                )
            }
        }

        completionHandler()
    }
}

extension Notification.Name {
    static let didTapPushNotification = Notification.Name("didTapPushNotification")
    static let didReceiveRemoteNotification = Notification.Name("didReceiveRemoteNotification")
}


