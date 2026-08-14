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

    /// フォアグラウンド滞在中に多重送信しないためのフラグ
    private static var hasRegisteredThisForegroundSession = false

    static func resetRegisteredToken() {
        hasRegisteredThisForegroundSession = false
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // バックグラウンドに入ったらフラグをリセット（次回フォアグラウンド復帰時にAPIを叩けるようにする）
        Self.hasRegisteredThisForegroundSession = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // フォアグラウンド復帰時にリモート通知登録をリクエストして最新トークンをサーバーへ同期
        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()

        // フォアグラウンド滞在中にすでに登録済みなら同一フォアグラウンドセッション内の多重呼び出しをスキップ
        if Self.hasRegisteredThisForegroundSession {
            return
        }

        #if DEBUG
        print("[APNs] Registering device token on foreground/launch: \(token)")
        #endif

        Task {
            do {
                try await APIClient.registerAPNsToken(token: token)
                Self.hasRegisteredThisForegroundSession = true
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
        completionHandler([.banner, .sound, .badge])
    }

    /// User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
