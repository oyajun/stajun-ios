import Foundation

/// The device holds the "true" study timer; the server is only an approximate
/// flag for other users. This persists the device-side study state so the timer
/// survives app launches and offline use.
enum LocalStudyStore {
    private static let startKey = "local_study_started_at"
    private static let offlineKey = "local_study_started_offline"
    private static let accumulatedKey = "local_study_accumulated_seconds"
    private static let segmentStartKey = "local_study_segment_started_at"
    private static let isPausedKey = "local_study_is_paused"

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
                clear()
            }
        }
    }

    /// The start time of the currently running segment (nil if paused or not studying).
    static var segmentStartedAt: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: segmentStartKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: segmentStartKey)
            } else {
                UserDefaults.standard.removeObject(forKey: segmentStartKey)
            }
        }
    }

    /// Total accumulated study time in seconds prior to the current segment.
    static var accumulatedSeconds: TimeInterval {
        get { UserDefaults.standard.double(forKey: accumulatedKey) }
        set { UserDefaults.standard.set(newValue, forKey: accumulatedKey) }
    }

    /// Whether the study session is currently paused.
    static var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: isPausedKey) }
        set { UserDefaults.standard.set(newValue, forKey: isPausedKey) }
    }

    /// Whether the current session was started offline and still needs to be
    /// reported to the server once connectivity returns.
    static var startedOffline: Bool {
        get { UserDefaults.standard.bool(forKey: offlineKey) }
        set { UserDefaults.standard.set(newValue, forKey: offlineKey) }
    }

    /// Calculate the current total elapsed study time in seconds.
    static func totalElapsedSeconds(at now: Date = Date()) -> TimeInterval {
        guard localStartedAt != nil else { return 0 }
        let acc = accumulatedSeconds
        if !isPaused {
            let seg = segmentStartedAt ?? localStartedAt
            if let seg {
                return acc + max(0, now.timeIntervalSince(seg))
            }
        }
        return acc
    }

    static func start(at date: Date = Date(), offline: Bool = false) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: startKey)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: segmentStartKey)
        UserDefaults.standard.set(0.0, forKey: accumulatedKey)
        UserDefaults.standard.set(false, forKey: isPausedKey)
        UserDefaults.standard.set(offline, forKey: offlineKey)
    }

    static func pause(at date: Date = Date()) {
        guard localStartedAt != nil else { return }
        if !isPaused {
            let seg = segmentStartedAt ?? localStartedAt
            if let seg {
                accumulatedSeconds += max(0, date.timeIntervalSince(seg))
            }
            segmentStartedAt = nil
            isPaused = true
        }
    }

    static func resume(at date: Date = Date()) {
        guard localStartedAt != nil else { return }
        if isPaused {
            segmentStartedAt = date
            isPaused = false
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: startKey)
        UserDefaults.standard.removeObject(forKey: offlineKey)
        UserDefaults.standard.removeObject(forKey: accumulatedKey)
        UserDefaults.standard.removeObject(forKey: segmentStartKey)
        UserDefaults.standard.removeObject(forKey: isPausedKey)
    }
}

