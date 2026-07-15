import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
    #else
    static let baseURL = URL(string: "https://YOUR_PRODUCTION_URL_HERE")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 10
}
