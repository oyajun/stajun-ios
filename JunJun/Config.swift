import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    //static let baseURL = URL(string: "http://192.168.0.219:3000")!
    #else
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 60
    
    /// App expiration date. Change this string to configure the expiration date.
    static let expirationDate: Date? = ISO8601DateFormatter().date(from: "2026-09-31T23:59:59Z")
    
    /// App Store URL for the update dialog
    static let appStoreURL = URL(string: "https://apps.apple.com/app/junjun-study-community/id6798144458")
    
    static func documentURL(for path: String) -> URL {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let supportedLangs = ["ja", "en", "ko"]
        let currentLang = supportedLangs.contains(lang) ? lang : "en"
        return baseURL.appendingPathComponent("\(currentLang)/\(path)")
    }
    
    static var privacyPolicyURL: URL {
        documentURL(for: "privacy-policy")
    }
    
    static var termsOfServiceURL: URL {
        documentURL(for: "terms-of-service")
    }
    
    static var supportURL: URL {
        documentURL(for: "support")
    }
}
