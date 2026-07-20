import Foundation
import Observation

/// One bar of the chart. `id` is the bucket start date string ("yyyy-MM-dd").
struct StatsChartItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let minutes: Int
}

/// State for the Stats screen: summary numbers plus a paged study-time chart.
///
/// The chart shows one fixed-size page of buckets at a time (e.g. 7 days,
/// 12 months). Each page is fetched once and cached; navigation just moves
/// the page anchor, so there is no scroll-position tracking or data merging.
@MainActor
@Observable
final class StatsModel {

    /// Identifies one page of the chart: a unit and the page's first bucket.
    struct PageKey: Hashable {
        let unit: ChartUnit
        let start: String
    }

    // MARK: - Summary

    private(set) var stats: StatsResponse?
    private(set) var isLoadingSummary = false
    private(set) var errorMessage: String?

    // MARK: - Chart paging

    var unit: ChartUnit = .day

    /// Last bucket of the visible page, per unit. Missing entry = latest page.
    private var pageEnds: [ChartUnit: Date] = [:]

    /// Fetched pages.
    private var pages: [PageKey: [StatsChartItem]] = [:]

    /// Start of the bucket containing today, for the current unit.
    private var currentBucket: Date { unit.startOfBucket(for: Date()) }

    var pageEnd: Date { pageEnds[unit] ?? currentBucket }
    var pageStart: Date { unit.bucket(-(unit.barsPerPage - 1), from: pageEnd) }
    var pageKey: PageKey { PageKey(unit: unit, start: Self.dayString(pageStart)) }

    /// Bars for the visible page, or nil while it is loading (or failed).
    var pageItems: [StatsChartItem]? { pages[pageKey] }

    var pageTotalMinutes: Int {
        pageItems?.reduce(0) { $0 + $1.minutes } ?? 0
    }

    /// X-axis domain covering every band of the page, including the full width
    /// of the last bucket (otherwise the chart clips today's bar and label).
    var pageDomain: ClosedRange<Date> {
        pageStart...unit.bucket(1, from: pageEnd)
    }

    var canGoForward: Bool { pageEnd < currentBucket }

    func goBack() {
        pageEnds[unit] = unit.bucket(-unit.barsPerPage, from: pageEnd)
    }

    func goForward() {
        guard canGoForward else { return }
        let next = unit.bucket(unit.barsPerPage, from: pageEnd)
        pageEnds[unit] = min(next, currentBucket)
    }

    // MARK: - Loading

    func loadSummary() async {
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        do {
            stats = try await APIClient.getStats()
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    /// Fetches the visible page unless it is already cached.
    func loadCurrentPage() async {
        let key = pageKey
        guard pages[key] == nil else { return }
        let start = pageStart
        let end = pageEnd

        do {
            let response = try await APIClient.getStatsSeries(
                unit: key.unit.rawValue,
                from: Self.dayString(start),
                to: Self.dayString(end)
            )
            let minutesByStart = Dictionary(
                response.buckets.map { ($0.start, $0.minutes) },
                uniquingKeysWith: { first, _ in first }
            )
            pages[key] = (0..<key.unit.barsPerPage).map { offset in
                let date = key.unit.bucket(offset, from: start)
                let id = Self.dayString(date)
                return StatsChartItem(id: id, date: date, minutes: minutesByStart[id] ?? 0)
            }
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    /// Pull-to-refresh: drop all cached pages and refetch summary + visible page.
    func refresh() async {
        pages.removeAll()
        await loadSummary()
        await loadCurrentPage()
    }

    // MARK: - Labels

    var pageRangeLabel: String {
        switch unit {
        case .day:
            return "\(monthDay(pageStart)) – \(monthDay(pageEnd))"
        case .week:
            // Show through the last day of the final week
            let lastDay = ChartUnit.calendar.date(byAdding: .day, value: 6, to: pageEnd) ?? pageEnd
            return "\(monthDay(pageStart)) – \(monthDay(lastDay))"
        case .month:
            let style = Date.FormatStyle.dateTime.year().month(.abbreviated)
            return "\(pageStart.formatted(style)) – \(pageEnd.formatted(style))"
        case .year:
            return "\(pageStart.formatted(.dateTime.year())) – \(pageEnd.formatted(.dateTime.year()))"
        }
    }

    private func monthDay(_ date: Date) -> String {
        let cal = ChartUnit.calendar
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return "\(m)/\(d)"
    }

    // MARK: - Helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func report(_ error: Error) {
        if !Self.isCancellation(error) {
            errorMessage = error.localizedDescription
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIError,
           case .networkError(let underlying) = apiError {
            return isCancellation(underlying)
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
