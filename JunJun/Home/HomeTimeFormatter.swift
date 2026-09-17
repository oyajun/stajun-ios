import Foundation

enum HomeTimeFormatter {
    /// Formats seconds into "h:mm:ss" or "mm:ss"
    static func formatElapsed(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    /// Formats elapsed time between two dates into "h:mm:ss" or "mm:ss"
    static func elapsedString(from start: Date, to current: Date) -> String {
        let seconds = max(0, Int(current.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private static let monthDayTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MdHm")
        return df
    }()

    private static let yearMonthDayTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("yMdHm")
        return df
    }()

    private static let postDateCache: NSCache<NSDate, NSString> = {
        let cache = NSCache<NSDate, NSString>()
        cache.countLimit = 500
        return cache
    }()

    /// Fast, cached relative/absolute date formatting for posts to avoid frame drops during scroll
    static func formatPostDate(_ date: Date) -> String {
        if let cached = postDateCache.object(forKey: date as NSDate) {
            return cached as String
        }
        let calendar = Calendar.current
        let now = Date()
        let result: String
        if calendar.isDate(date, inSameDayAs: now) {
            result = timeFormatter.string(from: date)
        } else {
            let createdYear = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: now)
            if createdYear == currentYear {
                result = monthDayTimeFormatter.string(from: date)
            } else {
                result = yearMonthDayTimeFormatter.string(from: date)
            }
        }
        postDateCache.setObject(result as NSString, forKey: date as NSDate)
        return result
    }
}
