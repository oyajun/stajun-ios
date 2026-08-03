import Foundation

/// The device holds the "true" study timer; the server is only an approximate
/// flag for other users. This persists the device-side study state so the timer
/// survives app launches and offline use.
enum LocalStudyStore {
    private static let startKey = "local_study_started_at"
    private static let offlineKey = "local_study_started_offline"

    /// The start time the device uses for measurement (nil = not studying).
    /// Independent of the server's `startedAt`.
    static var localStartedAt: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: startKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: startKey)
            } else {
                UserDefaults.standard.removeObject(forKey: startKey)
                UserDefaults.standard.removeObject(forKey: offlineKey)
            }
        }
    }

    /// Whether the current session was started offline and still needs to be
    /// reported to the server once connectivity returns.
    static var startedOffline: Bool {
        get { UserDefaults.standard.bool(forKey: offlineKey) }
        set { UserDefaults.standard.set(newValue, forKey: offlineKey) }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: startKey)
        UserDefaults.standard.removeObject(forKey: offlineKey)
    }
}
