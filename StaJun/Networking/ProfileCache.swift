import Foundation

/// Persists the signed-in user's profile so the app can stay usable
/// (and logged in) when the server is unreachable on launch.
enum ProfileCache {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("my_profile.json")
    }()

    static func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> UserProfile? {
        guard let data = try? Data(contentsOf: fileURL),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
