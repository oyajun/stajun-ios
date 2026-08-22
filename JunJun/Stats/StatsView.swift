import SwiftUI
import Charts

struct StatsView: View {
    @State private var model = StatsModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoadingSummary && model.stats == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle("")
            .task {
                await model.loadAll()
            }
            .task(id: model.pageKey) {
                await model.loadCurrentPage()
            }
            .refreshable {
                await model.refresh()
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let msg = model.errorMessage {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                summarySection
                heatmapSection
                chartCard
                // AdMob (審査通過後に復帰予定)
                // AdSmallBannerCard()
                if Config.isAffiliateAdVisible {
                    AffiliateBannerCard(cacheKey: "stats")
                }
            }
            .padding()
        }
    }

    // MARK: - Heatmap

    private let heatCellSize: CGFloat = 12
    private let heatCellSpacing: CGFloat = 3

    @ViewBuilder
    private var heatmapSection: some View {
        if model.isLoadingHeatmap && model.heatmapWeeks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else if !model.heatmapWeeks.isEmpty {
            heatmapCard
        }
    }

    private var heatmapCard: some View {
        HStack(alignment: .bottom, spacing: heatCellSpacing) {
            weekdayLabels
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    monthLabels
                    HStack(alignment: .top, spacing: heatCellSpacing) {
                        ForEach(model.heatmapWeeks) { week in
                            VStack(spacing: heatCellSpacing) {
                                ForEach(0..<7, id: \.self) { i in
                                    heatCell(week.days[i])
                                }
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Left-hand row labels: Monday first, every other day labeled.
    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: heatCellSpacing) {
            ForEach(Array(["Mon", "", "Wed", "", "Fri", "", "Sun"].enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(height: heatCellSize)
            }
        }
    }

    /// Month numbers above the column containing the 1st of each month.
    private var monthLabels: some View {
        HStack(spacing: heatCellSpacing) {
            ForEach(model.heatmapWeeks) { week in
                Text(monthLabel(for: week))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: heatCellSize, height: 10, alignment: .leading)
            }
        }
    }

    private func monthLabel(for week: HeatmapWeek) -> String {
        let cal = ChartUnit.calendar
        for day in week.days {
            if let day, cal.component(.day, from: day.date) == 1 {
                return "\(cal.component(.month, from: day.date))"
            }
        }
        return ""
    }

    @ViewBuilder
    private func heatCell(_ day: HeatmapDay?) -> some View {
        if let day {
            RoundedRectangle(cornerRadius: 2)
                .fill(heatColor(minutes: day.minutes))
                .frame(width: heatCellSize, height: heatCellSize)
        } else {
            Color.clear
                .frame(width: heatCellSize, height: heatCellSize)
        }
    }

    private func heatColor(minutes: Int) -> Color {
        guard minutes > 0 else { return Color(.systemGray5) }
        let ratio = Double(minutes) / Double(max(model.heatmapMaxMinutes, 1))
        if ratio > 0.75 { return .green }
        if ratio > 0.5  { return .green.opacity(0.7) }
        if ratio > 0.25 { return .green.opacity(0.45) }
        return .green.opacity(0.25)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let stats = model.stats {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    StatItem(title: "Total",       minutes: stats.totalMinutes)
                    StatItem(title: "This Month",  minutes: stats.monthMinutes)
                }
                HStack(spacing: 0) {
                    StatItem(title: "This Week",   minutes: stats.weekMinutes)
                    StatItem(title: "Today",       minutes: stats.todayMinutes)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $model.unit) {
                ForEach(ChartUnit.allCases, id: \.self) { Text(LocalizedStringKey($0.label)).tag($0) }
            }
            .pickerStyle(.segmented)

            pageHeader
            chartContent
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var pageHeader: some View {
        HStack {
            pageButton(systemName: "chevron.left", enabled: true) {
                model.goBack()
            }

            Spacer()

            VStack(spacing: 2) {
                Text(model.pageRangeLabel)
                    .font(.subheadline.weight(.medium))
                Text(formatMinutes(model.pageTotalMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            pageButton(systemName: "chevron.right", enabled: model.canGoForward) {
                model.goForward()
            }
        }
        .buttonStyle(.borderless)
    }

    private func pageButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }

    @ViewBuilder
    private var chartContent: some View {
        if let items = model.pageItems {
            chart(items: items)
        } else if model.errorMessage != nil {
            VStack(spacing: 8) {
                Text("Could not load data")
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await model.loadCurrentPage() }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        }
    }

    private struct YAxisScale {
        let top: Int
        let values: [Int]
    }

    private func calculateYAxisScale(maxMinutes: Int) -> YAxisScale {
        let rawHours = max(1, Int(ceil(Double(maxMinutes) / 60.0)))

        let stepHours: Int
        if rawHours <= 15 {
            stepHours = 1
        } else if rawHours <= 30 {
            stepHours = 5
        } else if rawHours <= 60 {
            stepHours = 10
        } else if rawHours <= 120 {
            stepHours = 20
        } else if rawHours <= 300 {
            stepHours = 50
        } else if rawHours <= 600 {
            stepHours = 100
        } else {
            stepHours = 200
        }

        let stepMinutes = stepHours * 60
        let count = max(1, Int(ceil(Double(maxMinutes) / Double(stepMinutes))))
        let topMinutes = count * stepMinutes

        let values = stride(from: 0, through: topMinutes, by: stepMinutes).map { $0 }
        return YAxisScale(top: topMinutes, values: values)
    }

    private func chart(items: [StatsChartItem]) -> some View {
        let unit = model.unit
        let maxMinutes = items.map(\.minutes).max() ?? 0
        let yScale = calculateYAxisScale(maxMinutes: maxMinutes)
        let domain = model.pageDomain
        // Centered axis labels render between a mark and the next one, so the
        // last bucket needs a sentinel mark at the domain end to get a label.
        let axisDates = items.map(\.date) + [domain.upperBound]

        return Chart(items) { item in
            BarMark(
                x: .value("Date", item.date, unit: unit.calendarComponent),
                y: .value("Minutes", item.minutes)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(3)
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...yScale.top)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel(centered: true) {
                    // Skip the sentinel mark at the domain end
                    if let date = value.as(Date.self), date < domain.upperBound {
                        Text(xAxisLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: yScale.values) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text(yAxisLabel(minutes))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 220)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) else { return }
                    if dx > 40 {
                        withAnimation(.snappy) { model.goBack() }
                    } else if dx < -40 {
                        withAnimation(.snappy) { model.goForward() }
                    }
                }
        )
    }

    private func xAxisLabel(for date: Date) -> String {
        let cal = ChartUnit.calendar
        switch model.unit {
        case .day, .week:
            // "M/d" without leading zeros
            return "\(cal.component(.month, from: date))/\(cal.component(.day, from: date))"
        case .month:
            return "\(cal.component(.month, from: date))"
        case .year:
            return date.formatted(.dateTime.year())
        }
    }

    private func yAxisLabel(_ minutes: Int) -> LocalizedStringKey {
        if minutes == 0 { return "0" }
        return "\(minutes / 60)h"
    }
}

// MARK: - StatItem

private struct StatItem: View {
    let title: LocalizedStringKey
    let minutes: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatMinutes(minutes))
                .font(.headline.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// "1h 30m" style duration used by the summary cards and the page total.
private func formatMinutes(_ minutes: Int) -> LocalizedStringKey {
    guard minutes > 0 else { return "0m" }
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

#Preview {
    StatsView()
        .environment(AppState())
}
