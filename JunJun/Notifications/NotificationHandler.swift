import Foundation
import UIKit
import UserNotifications

final class NotificationHandler: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// 最後にサーバーへの登録に成功した APNs トークン
    private static var lastRegisteredToken: String?

    /// OS から受信した最新の APNs トークン（未ログイン時などの保留用）
    private static var pendingDeviceToken: String?

    /// トークン登録の排他制御用（現在進行中の Task）
    private static var activeRegistrationTask: Task<Void, Never>?

    /// 登録キャッシュのリセット（ログアウト時やアカウント削除時に呼び出し）
    static func resetRegisteredToken() {
        lastRegisteredToken = nil
        // pendingDeviceToken（端末の最新トークン）は保持し、再ログイン時に新ユーザーへ即時紐付け可能にする
        activeRegistrationTask?.cancel()
        activeRegistrationTask = nil
    }

    /// ログイン完了時などに、未送信トークンがあればサーバーへ同期する
    static func syncPendingTokenIfNeeded() {
        guard let token = pendingDeviceToken ?? lastRegisteredToken else { return }
        registerTokenIfNeeded(token: token)
    }

    /// トークンをサーバーへ登録（排他制御・重複チェック付き）
    static func registerTokenIfNeeded(token: String) {
        // 未ログイン時はトークンのみ保持して終了（ログイン後に syncPendingTokenIfNeeded で送信）
        guard KeychainHelper.token != nil else {
            pendingDeviceToken = token
            #if DEBUG
            print("[APNs] Token received but user not logged in yet. Saved as pending token.")
            #endif
            return
        }

        // 既に同じトークンが登録完了している場合はスキップ
        if lastRegisteredToken == token {
            #if DEBUG
            print("[APNs] Token already registered on server: \(token)")
            #endif
            return
        }

        // すでに登録処理が進行中の場合、多重リクエストをスキップ
        if activeRegistrationTask != nil {
            #if DEBUG
            print("[APNs] Registration already in progress, skipping duplicate call.")
            #endif
            return
        }

        pendingDeviceToken = token

        #if DEBUG
        print("[APNs] Registering device token on server: \(token)")
        #endif

        activeRegistrationTask = Task {
            defer {
                activeRegistrationTask = nil
            }

            do {
                try await APIClient.registerAPNsToken(token: token)
                lastRegisteredToken = token
                #if DEBUG
                print("[APNs] Device token sent to server successfully.")
                #endif
            } catch {
                #if DEBUG
                print("[APNs] Failed to send device token to server: \(error)")
                #endif
            }
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

        Self.registerTokenIfNeeded(token: token)
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


