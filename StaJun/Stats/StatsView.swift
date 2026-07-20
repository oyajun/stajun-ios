import SwiftUI
import Charts

private enum DateFormatters {
    static let localDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
}

private struct StatsChartItem: Identifiable, Equatable {
    let id: String
    let start: String
    let end: String
    let minutes: Int
    let date: Date
}

private struct UnitState {
    var chartItems: [StatsChartItem] = []
    var fetchedStarts: Set<String> = []
    var scrollPositionStart: Date = Date()
    var oldestSearchedDate: Date? = nil
    var hasFetchedInitial: Bool = false
}

struct StatsView: View {
    private enum ChartUnit: String, CaseIterable {
        case day, week, month, year

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

        // Buckets visible in one window
        var visibleCount: Int {
            switch self {
            case .day:   return 7
            case .week:  return 8
            case .month: return 6
            case .year:  return 5
            }
        }

        // Seconds for chartXVisibleDomain
        var visibleDomainSeconds: Double {
            let day: Double = 86400
            switch self {
            case .day:   return 7   * day
            case .week:  return 56  * day
            case .month: return 183 * day
            case .year:  return 5 * 365 * day
            }
        }

        // Total historical buckets to pre-allocate in frame (keeps chart coordinates completely stable)
        var frameLookbackCount: Int {
            switch self {
            case .day:   return 120   // ~4 months (fast & smooth)
            case .week:  return 156   // 3 years
            case .month: return 60    // 5 years
            case .year:  return 10    // 10 years
            }
        }

        // Buckets to fetch per page when scrolling back
        var pageCount: Int {
            switch self {
            case .day:   return 30
            case .week:  return 24
            case .month: return 12
            case .year:  return 5
            }
        }

        var snapComponents: DateComponents {
            switch self {
            case .day:   return DateComponents(hour: 0, minute: 0, second: 0)
            case .week:  return DateComponents(hour: 0, weekday: 2) // Monday
            case .month: return DateComponents(day: 1, hour: 0)
            case .year:  return DateComponents(month: 1, day: 1, hour: 0)
            }
        }
    }

    @State private var stats: StatsResponse?
    @State private var chartItems: [StatsChartItem] = []
    @State private var fetchedStarts: Set<String> = []
    @State private var chartUnit: ChartUnit = .day
    @State private var unitStates: [ChartUnit: UnitState] = [:]
    @State private var isLoadingStats = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var scrollPositionStart: Date = Date()
    @State private var oldestSearchedDate: Date?

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingStats && stats == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .navigationTitle("Stats")
            .task {
                await loadStats()
                await initialLoadSeries()
            }
            .refreshable {
                await loadStats()
                await refreshSeries()
            }
            .onChange(of: chartUnit) { oldUnit, newUnit in
                switchToUnit(newUnit, oldUnit: oldUnit)
            }
        }
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let msg = errorMessage {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                summarySection
                chartSection
            }
            .padding()
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let stats {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Total",  minutes: stats.totalMinutes)
                StatCard(title: "Month",  minutes: stats.monthMinutes)
                StatCard(title: "Week",   minutes: stats.weekMinutes)
                StatCard(title: "Today",  minutes: stats.todayMinutes)
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Study Time")
                    .font(.headline)
                Spacer()
                if isLoadingMore {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading history…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }

            Picker("Period", selection: $chartUnit) {
                ForEach(ChartUnit.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            chartContent
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoadingMore && chartItems.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        } else if chartItems.isEmpty {
            Text("No data")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        } else {
            studyChart
        }
    }

    private var studyChart: some View {
        Chart(chartItems) { item in
            BarMark(
                x: .value("date", item.date, unit: chartUnit.calendarComponent),
                y: .value("min", item.minutes)
            )
            .foregroundStyle(Color.accentColor.gradient)
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: chartUnit.visibleDomainSeconds)
        .chartScrollPosition(x: $scrollPositionStart)
        .chartScrollTargetBehavior(
            .valueAligned(matching: chartUnit.snapComponents, majorAlignment: .matching(chartUnit.snapComponents))
        )
        .chartXAxis {
            if chartUnit == .year {
                AxisMarks(values: .stride(by: .year)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.year()))
                                .font(.caption2)
                        }
                    }
                }
            } else if chartUnit == .month {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .font(.caption2)
                        }
                    }
                }
            } else {
                // day and week: "M/d" without leading zeros
                AxisMarks(values: .stride(by: chartUnit == .week ? .weekOfYear : .day)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let cal = Calendar.current
                            Text("\(cal.component(.month, from: date))/\(cal.component(.day, from: date))")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let m = value.as(Int.self) {
                        Text(m >= 60 ? "\(m / 60)h" : "\(m)m").font(.caption2)
                    }
                }
            }
        }
        .frame(height: 220)
        .onChange(of: scrollPositionStart) { _, newStart in
            triggerLoadMoreIfNeeded(leadingEdge: newStart)
        }
    }

    // MARK: - Unit Switch & Caching

    private func saveCurrentUnitState(for unit: ChartUnit) {
        unitStates[unit] = UnitState(
            chartItems: chartItems,
            fetchedStarts: fetchedStarts,
            scrollPositionStart: scrollPositionStart,
            oldestSearchedDate: oldestSearchedDate,
            hasFetchedInitial: true
        )
    }

    private func switchToUnit(_ newUnit: ChartUnit, oldUnit: ChartUnit) {
        saveCurrentUnitState(for: oldUnit)

        if let saved = unitStates[newUnit], saved.hasFetchedInitial {
            chartItems = saved.chartItems
            fetchedStarts = saved.fetchedStarts
            scrollPositionStart = saved.scrollPositionStart
            oldestSearchedDate = saved.oldestSearchedDate
            isLoadingMore = false
        } else {
            chartItems = []
            fetchedStarts = []
            oldestSearchedDate = nil
            isLoadingMore = false
            Task { await initialLoadSeries() }
        }
    }

    // MARK: - Scroll Load Trigger

    private func triggerLoadMoreIfNeeded(leadingEdge: Date) {
        guard !isLoadingMore else { return }
        
        let leadingEdgeNormalized = startOfPeriod(for: leadingEdge, unit: chartUnit)
        let leadingEdgeStr = DateFormatters.localDate.string(from: leadingEdgeNormalized)
        
        if !fetchedStarts.contains(leadingEdgeStr) {
            isLoadingMore = true
            Task {
                await loadMoreBuckets(around: leadingEdgeNormalized)
            }
        }
    }

    // MARK: - Data Loading

    private func loadStats() async {
        isLoadingStats = true
        errorMessage = nil
        defer { isLoadingStats = false }
        do {
            stats = try await APIClient.getStats()
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshSeries() async {
        let unit = chartUnit
        let calendar = Calendar.current
        let todayNormalized = startOfPeriod(for: Date(), unit: unit)

        // Refetch the full previously searched range up to today without clearing existing chart items
        let from: Date
        if let oldest = oldestSearchedDate {
            from = oldest
        } else {
            switch unit {
            case .day:   from = calendar.date(byAdding: .day,        value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
            case .week:  from = calendar.date(byAdding: .weekOfYear, value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
            case .month: from = calendar.date(byAdding: .month,      value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
            case .year:  from = calendar.date(byAdding: .year,       value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
            }
        }
        let fromNormalized = startOfPeriod(for: from, unit: unit)

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await APIClient.getStatsSeries(
                unit: unit.rawValue,
                from: DateFormatters.localDate.string(from: fromNormalized),
                to: DateFormatters.localDate.string(from: todayNormalized)
            )

            guard chartUnit == unit else { return }

            mergeBuckets(response.buckets)
            saveCurrentUnitState(for: unit)
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func initialLoadSeries() async {
        let unit = chartUnit
        let calendar = Calendar.current
        let todayNormalized = startOfPeriod(for: Date(), unit: unit)

        if chartItems.isEmpty {
            chartItems = buildChartItemsFrame(for: unit)
        }

        // Initial fetch window
        let from: Date
        switch unit {
        case .day:
            from = calendar.date(byAdding: .day, value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
        case .week:
            from = calendar.date(byAdding: .weekOfYear, value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
        case .month:
            from = calendar.date(byAdding: .month, value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
        case .year:
            if let fp = stats?.firstPostDate.flatMap({ DateFormatters.localDate.date(from: $0) }) {
                from = fp
            } else {
                from = calendar.date(byAdding: .year, value: -(unit.pageCount - 1), to: todayNormalized) ?? todayNormalized
            }
        }
        let fromNormalized = startOfPeriod(for: from, unit: unit)

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await APIClient.getStatsSeries(
                unit: unit.rawValue,
                from: DateFormatters.localDate.string(from: fromNormalized),
                to: DateFormatters.localDate.string(from: todayNormalized)
            )

            guard chartUnit == unit else { return }

            let leadingEdge = calendar.date(
                byAdding: unit.calendarComponent,
                value: -(unit.visibleCount - 1),
                to: todayNormalized
            ) ?? todayNormalized
            let leadingEdgeNormalized = startOfPeriod(for: leadingEdge, unit: unit)

            scrollPositionStart = leadingEdgeNormalized
            mergeBuckets(response.buckets)
            oldestSearchedDate = fromNormalized
            saveCurrentUnitState(for: unit)
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadMoreBuckets(around date: Date) async {
        defer { isLoadingMore = false }

        let unit = chartUnit
        let calendar = Calendar.current
        let targetNormalized = startOfPeriod(for: date, unit: unit)

        let toNormalized = targetNormalized
        let from: Date
        switch unit {
        case .day:   from = calendar.date(byAdding: .day,        value: -(unit.pageCount - 1), to: toNormalized) ?? toNormalized
        case .week:  from = calendar.date(byAdding: .weekOfYear, value: -(unit.pageCount - 1), to: toNormalized) ?? toNormalized
        case .month: from = calendar.date(byAdding: .month,      value: -(unit.pageCount - 1), to: toNormalized) ?? toNormalized
        case .year:  from = calendar.date(byAdding: .year,       value: -(unit.pageCount - 1), to: toNormalized) ?? toNormalized
        }
        let fromNormalized = startOfPeriod(for: from, unit: unit)

        do {
            let response = try await APIClient.getStatsSeries(
                unit: unit.rawValue,
                from: DateFormatters.localDate.string(from: fromNormalized),
                to: DateFormatters.localDate.string(from: toNormalized)
            )

            guard chartUnit == unit else { return }

            mergeBuckets(response.buckets)
            if oldestSearchedDate == nil || fromNormalized < oldestSearchedDate! {
                oldestSearchedDate = fromNormalized
            }
            saveCurrentUnitState(for: unit)
        } catch {
            // Silent error for pagination cancellation
        }
    }

    // MARK: - Frame Generation & Merging

    private func buildChartItemsFrame(for unit: ChartUnit) -> [StatsChartItem] {
        let calendar = Calendar.current
        let todayNormalized = startOfPeriod(for: Date(), unit: unit)
        let count = unit.frameLookbackCount
        
        var list: [StatsChartItem] = []
        list.reserveCapacity(count)

        for i in (0..<count).reversed() {
            let d: Date
            switch unit {
            case .day:   d = calendar.date(byAdding: .day,        value: -i, to: todayNormalized) ?? todayNormalized
            case .week:  d = calendar.date(byAdding: .weekOfYear, value: -i, to: todayNormalized) ?? todayNormalized
            case .month: d = calendar.date(byAdding: .month,      value: -i, to: todayNormalized) ?? todayNormalized
            case .year:  d = calendar.date(byAdding: .year,       value: -i, to: todayNormalized) ?? todayNormalized
            }
            let normalized = startOfPeriod(for: d, unit: unit)
            let dateStr = DateFormatters.localDate.string(from: normalized)
            list.append(StatsChartItem(id: dateStr, start: dateStr, end: dateStr, minutes: 0, date: normalized))
        }
        return list
    }

    private func mergeBuckets(_ newBuckets: [StatsBucket]) {
        guard !newBuckets.isEmpty else { return }
        
        let updates = Dictionary(uniqueKeysWithValues: newBuckets.map { ($0.start, $0.minutes) })
        for b in newBuckets {
            fetchedStarts.insert(b.start)
        }

        // Update values in-place without changing array size or index order
        chartItems = chartItems.map { existing in
            if let newMinutes = updates[existing.start] {
                return StatsChartItem(id: existing.id, start: existing.start, end: existing.end, minutes: newMinutes, date: existing.date)
            }
            return existing
        }
    }

    // MARK: - Helpers

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIError {
            if case .networkError(let underlying) = apiError {
                return isCancellationError(underlying)
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        return false
    }

    private func startOfPeriod(for date: Date, unit: ChartUnit) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday start (ISO 8601)
        calendar.timeZone = TimeZone.current

        let startOfDay = calendar.startOfDay(for: date)

        switch unit {
        case .day:
            return startOfDay
        case .week:
            let weekday = calendar.component(.weekday, from: startOfDay)
            let daysToSubtract = (weekday + 5) % 7
            return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay) ?? startOfDay
        case .month:
            let components = calendar.dateComponents([.year, .month], from: startOfDay)
            return calendar.date(from: components) ?? startOfDay
        case .year:
            let components = calendar.dateComponents([.year], from: startOfDay)
            return calendar.date(from: components) ?? startOfDay
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let minutes: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formatDuration(minutes))
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

#Preview {
    StatsView()
        .environment(AppState())
}
