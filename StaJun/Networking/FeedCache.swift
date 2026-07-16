import Foundation

/// Persists the home feed to disk so following users' last-known status
/// is available while offline.
enum FeedCache {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("home_feed.json")
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

    /// Saves the feed. Failures are ignored — caching is best-effort.
    static func save(_ users: [UserWithStudyStatus]) {
        guard let data = try? encoder.encode(users) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Loads the last cached feed, or an empty array if none exists.
    static func load() -> [UserWithStudyStatus] {
        guard let data = try? Data(contentsOf: fileURL),
              let users = try? decoder.decode([UserWithStudyStatus].self, from: data)
        else { return [] }
        return users
    }

    /// Removes the cached feed (e.g. on sign-out).
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
