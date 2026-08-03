import Foundation

/// Display unit for the study-time chart. Each unit shows a fixed number of
/// bars per page; navigation steps by whole pages.
enum ChartUnit: String, CaseIterable {
    case day, week, month, year

    /// Calendar with Monday week start (ISO 8601) in the local time zone.
    static let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    var label: String {
        switch self {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }

    /// Number of bars shown on one page.
    var barsPerPage: Int {
        switch self {
        case .day:   return 7
        case .week:  return 8
        case .month: return 12
        case .year:  return 5
        }
    }

    /// Snaps a date to the start of the bucket containing it.
    func startOfBucket(for date: Date) -> Date {
        Self.calendar.dateInterval(of: calendarComponent, for: date)?.start
            ?? Self.calendar.startOfDay(for: date)
    }

    /// The bucket start `offset` buckets away from `date` (itself a bucket start).
    func bucket(_ offset: Int, from date: Date) -> Date {
        guard let shifted = Self.calendar.date(byAdding: calendarComponent, value: offset, to: date) else {
            return date
        }
        return startOfBucket(for: shifted)
    }
}
