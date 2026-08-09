import Foundation
import Observation

/// One bar of the chart. `id` is the bucket start date string ("yyyy-MM-dd").
struct StatsChartItem: Identifiable, Equatable, Codable {
    let id: String
    let date: Date
    let minutes: Int
}

/// One day of the annual heatmap.
struct HeatmapDay: Identifiable, Equatable, Codable {
    let id: String   // "yyyy-MM-dd"
    let date: Date
    let minutes: Int
}

/// One column of the annual heatmap: a Monday-to-Sunday week.
struct HeatmapWeek: Identifiable, Equatable, Codable {
    let id: String            // week start "yyyy-MM-dd"
    let days: [HeatmapDay?]   // always 7 entries, Monday first; nil = outside range
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

    // MARK: - Heatmap (annual view)

    private(set) var heatmapWeeks: [HeatmapWeek] = []
    private(set) var heatmapMaxMinutes = 0
    private(set) var isLoadingHeatmap = false

    init() {
        if let cachedSummary = StatsCache.loadSummary() {
            self.stats = cachedSummary
        }
        if let cachedHeatmap = StatsCache.loadHeatmap() {
            self.heatmapWeeks = cachedHeatmap.weeks
            self.heatmapMaxMinutes = cachedHeatmap.maxMinutes
        }
        let cachedPages = StatsCache.loadChartPages()
        for (keyStr, items) in cachedPages {
            let parts = keyStr.split(separator: ":")
            if parts.count == 2, let unit = ChartUnit(rawValue: String(parts[0])) {
                let key = PageKey(unit: unit, start: String(parts[1]))
                self.pages[key] = items
            }
        }
    }

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

    /// Loads the summary and heatmap concurrently.
    func loadAll() async {
        async let summary: Void = loadSummary()
        async let heatmap: Void = loadHeatmap()
        _ = await (summary, heatmap)
    }

    func loadSummary() async {
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        do {
            let res = try await APIClient.getStats()
            stats = res
            StatsCache.saveSummary(res)
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    /// Loads the past 365 days and lays them out as Monday-first week columns.
    func loadHeatmap() async {
        isLoadingHeatmap = true
        defer { isLoadingHeatmap = false }
        let cal = ChartUnit.calendar
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -364, to: today) ?? today
        do {
            let response = try await APIClient.getStatsSeries(
                unit: "day",
                from: Self.dayString(start),
                to: Self.dayString(today)
            )
            let minutesByStart = Dictionary(
                response.buckets.map { ($0.start, $0.minutes) },
                uniquingKeysWith: { first, _ in first }
            )

            var weeks: [HeatmapWeek] = []
            var weekStart = ChartUnit.week.startOfBucket(for: start)
            while weekStart <= today {
                let days: [HeatmapDay?] = (0..<7).map { offset in
                    guard let day = cal.date(byAdding: .day, value: offset, to: weekStart),
                          day >= start, day <= today else { return nil }
                    let id = Self.dayString(day)
                    return HeatmapDay(id: id, date: day, minutes: minutesByStart[id] ?? 0)
                }
                weeks.append(HeatmapWeek(id: Self.dayString(weekStart), days: days))
                guard let next = cal.date(byAdding: .day, value: 7, to: weekStart) else { break }
                weekStart = next
            }
            heatmapWeeks = weeks
            let maxMin = weeks.flatMap(\.days).compactMap { $0?.minutes }.max() ?? 0
            heatmapMaxMinutes = maxMin
            StatsCache.saveHeatmap(weeks: weeks, maxMinutes: maxMin)
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
            saveChartPagesToDisk()
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    private func saveChartPagesToDisk() {
        var dict: [String: [StatsChartItem]] = [:]
        for (key, items) in pages {
            dict["\(key.unit.rawValue):\(key.start)"] = items
        }
        StatsCache.saveChartPages(dict)
    }

    /// Pull-to-refresh: drop all cached pages and refetch summary + heatmap + visible page.
    func refresh() async {
        pages.removeAll()
        await loadAll()
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
        if !error.isCancellation {
            errorMessage = error.localizedDescription
        }
    }
}
