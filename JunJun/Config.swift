import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "https://stajun.netlify.app")!
    //static let baseURL = URL(string: "http://192.168.0.219:3000")!
    #else
    static let baseURL = URL(string: "https://stajun.netlify.app")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 60
}
