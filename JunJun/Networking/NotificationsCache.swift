import Foundation

/// Persists notifications to disk for instant offline/cached viewing.
enum NotificationsCache {
    private static let cacheDir: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static var fileURL: URL {
        cacheDir.appendingPathComponent("notifications.json")
    }

    /// Saves notifications to cache. Best-effort.
    static func save(_ notifications: [AppNotification]) {
        guard let data = try? encoder.encode(notifications) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Loads cached notifications from disk.
    static func load() -> [AppNotification] {
        guard let data = try? Data(contentsOf: fileURL),
              let notifications = try? decoder.decode([AppNotification].self, from: data)
        else { return [] }
        return notifications
    }

    /// Clears cached notifications.
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
