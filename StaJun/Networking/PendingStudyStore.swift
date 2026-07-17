import Foundation

/// Persists a study session that was started while offline, so its start time
/// can be sent to the server once connectivity returns (even across app launches).
enum PendingStudyStore {
    private static let key = "pending_study_started_at"

    /// The start time of a locally-started (not yet synced) study session, if any.
    static var pendingStart: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: key)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
