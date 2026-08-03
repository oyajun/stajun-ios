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
    
    /// App expiration date. Change this string to configure the expiration date.
    static let expirationDate: Date? = ISO8601DateFormatter().date(from: "2026-08-31T23:59:59Z")
    
    /// App Store URL for the update dialog
    static let appStoreURL = URL(string: "itms-apps://itunes.apple.com/")
}
