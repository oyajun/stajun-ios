import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
    #else
    static let baseURL = URL(string: "https://YOUR_PRODUCTION_URL_HERE")!
    #endif

    /// ホームフィードのポーリング間隔（秒）
    static let feedPollingInterval: TimeInterval = 10
}
