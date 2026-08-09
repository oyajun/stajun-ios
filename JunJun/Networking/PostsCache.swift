import Foundation

/// Persists timeline posts to disk for different scopes ("following", "mine", "user_{userId}").
enum PostsCache {
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

    private static func fileURL(for scopeKey: String) -> URL {
        cacheDir.appendingPathComponent("posts_\(scopeKey).json")
    }

    /// Saves posts for a given scope key. Best-effort.
    static func save(_ posts: [Post], scopeKey: String) {
        let url = fileURL(for: scopeKey)
        guard let data = try? encoder.encode(posts) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Loads cached posts for a given scope key.
    static func load(scopeKey: String) -> [Post] {
        let url = fileURL(for: scopeKey)
        guard let data = try? Data(contentsOf: url),
              let posts = try? decoder.decode([Post].self, from: data)
        else { return [] }
        return posts
    }

    /// Removes cached posts for a specific scope key or all scope keys.
    static func clear(scopeKey: String? = nil) {
        if let scopeKey {
            try? FileManager.default.removeItem(at: fileURL(for: scopeKey))
        } else {
            let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("posts_") && file.pathExtension == "json" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
