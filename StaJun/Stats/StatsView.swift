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
                await model.loadSummary()
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
                chartCard
            }
            .padding()
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let stats = model.stats {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Total",  minutes: stats.totalMinutes)
                StatCard(title: "Month",  minutes: stats.monthMinutes)
                StatCard(title: "Week",   minutes: stats.weekMinutes)
                StatCard(title: "Today",  minutes: stats.todayMinutes)
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $model.unit) {
                ForEach(ChartUnit.allCases, id: \.self) { Text($0.label).tag($0) }
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

    private func chart(items: [StatsChartItem]) -> some View {
        let unit = model.unit
        let maxMinutes = items.map(\.minutes).max() ?? 0
        // Round the top of the y axis up to a whole hour (minimum one hour)
        let yTop = max(60, Int((Double(maxMinutes) / 60).rounded(.up)) * 60)
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
        .chartYScale(domain: 0...yTop)
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
            AxisMarks { value in
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

    private func yAxisLabel(_ minutes: Int) -> String {
        if minutes == 0 { return "0" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes.isMultiple(of: 60) { return "\(minutes / 60)h" }
        return String(format: "%.1fh", Double(minutes) / 60)
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
            Text(formatMinutes(minutes))
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// "1h 30m" style duration used by the summary cards and the page total.
private func formatMinutes(_ minutes: Int) -> String {
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
