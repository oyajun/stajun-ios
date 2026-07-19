import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "https://stajun.netlify.app")!
    #else
    static let baseURL = URL(string: "https://stajun.netlify.app")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 60
}
