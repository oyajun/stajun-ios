import Foundation

/// Persists viewed user profiles to disk so profile screens load instantly.
enum UserProfileCache {
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

    private static func fileURL(for userId: String) -> URL {
        cacheDir.appendingPathComponent("user_profile_\(userId).json")
    }

    static func save(_ user: UserWithStudyStatus, userId: String) {
        let url = fileURL(for: userId)
        guard let data = try? encoder.encode(user) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(userId: String) -> UserWithStudyStatus? {
        let url = fileURL(for: userId)
        guard let data = try? Data(contentsOf: url),
              let user = try? decoder.decode(UserWithStudyStatus.self, from: data)
        else { return nil }
        return user
    }

    static func clear() {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("user_profile_") && file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
