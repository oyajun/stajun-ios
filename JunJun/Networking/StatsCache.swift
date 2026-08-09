import Foundation

struct HeatmapCacheData: Codable {
    let weeks: [HeatmapWeek]
    let maxMinutes: Int
}

/// Persists stats summary, heatmap data, and chart pages to disk.
enum StatsCache {
    private static let cacheDir: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }()

    private static let summaryURL = cacheDir.appendingPathComponent("stats_summary.json")
    private static let heatmapURL = cacheDir.appendingPathComponent("stats_heatmap.json")
    private static let chartPagesURL = cacheDir.appendingPathComponent("stats_chart_pages.json")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func saveSummary(_ stats: StatsResponse) {
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: summaryURL, options: .atomic)
    }

    static func loadSummary() -> StatsResponse? {
        guard let data = try? Data(contentsOf: summaryURL),
              let stats = try? decoder.decode(StatsResponse.self, from: data)
        else { return nil }
        return stats
    }

    static func saveHeatmap(weeks: [HeatmapWeek], maxMinutes: Int) {
        let cacheData = HeatmapCacheData(weeks: weeks, maxMinutes: maxMinutes)
        guard let data = try? encoder.encode(cacheData) else { return }
        try? data.write(to: heatmapURL, options: .atomic)
    }

    static func loadHeatmap() -> HeatmapCacheData? {
        guard let data = try? Data(contentsOf: heatmapURL),
              let cacheData = try? decoder.decode(HeatmapCacheData.self, from: data)
        else { return nil }
        return cacheData
    }

    static func saveChartPages(_ pages: [String: [StatsChartItem]]) {
        guard let data = try? encoder.encode(pages) else { return }
        try? data.write(to: chartPagesURL, options: .atomic)
    }

    static func loadChartPages() -> [String: [StatsChartItem]] {
        guard let data = try? Data(contentsOf: chartPagesURL),
              let pages = try? decoder.decode([String: [StatsChartItem]].self, from: data)
        else { return [:] }
        return pages
    }

    static func clear() {
        try? FileManager.default.removeItem(at: summaryURL)
        try? FileManager.default.removeItem(at: heatmapURL)
        try? FileManager.default.removeItem(at: chartPagesURL)
    }
}
