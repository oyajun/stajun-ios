import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    //static let baseURL = URL(string: "http://192.168.128.105:3000")!
    #else
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 60
    
    // MARK: - RevenueCat / Subscriptions
    /// RevenueCat Public iOS API Key
    static let revenueCatAPIKey: String = "appl_xiFBjWtErZPknXMcktQCnDoRyym"
    /// RevenueCat Entitlement ID for Pro subscription
    static let proEntitlementID: String = "junjun_pro"
    /// App Store Product ID for Monthly Pro Subscription
    static let proProductID: String = "com.oyajun.junjunapp.pro.monthly"
    /// Default fallback price display
    static let proMonthlyFallbackPrice: String = "¥300"
    
    /// Global flag to enable or disable ad displays app-wide
    static let showAds: Bool = true

    /// Whether the user is in Japan region
    static var isJapanRegion: Bool {
        Locale.current.region?.identifier == "JP"
    }

    /// Whether affiliate ads should be displayed (enabled and in Japan region)
    static var isAffiliateAdVisible: Bool {
        showAds && isJapanRegion
    }
    
    /// Google AdMob Banner Ad Unit ID (Test ID by default)
    static let adMobBannerUnitID: String = "ca-app-pub-5564838687301652/5099285563"
    
    /// Keywords passed to AdMob to prioritize study & education related ads
    static let adMobKeywords: [String] = ["TOEIC", "book", "apple", "student"]
    
    /// Affiliate items displayed in banners
    static let affiliateItems: [AffiliateItem] = [
        AffiliateItem(
            id: "rakuten-gold-phrase",
            title: "出る単特急 金のフレーズ 増補改訂版 （TOEIC L＆R TEST）",
            priceAndShipping: "990円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=21833920&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F4640%2F9784023324640_1_2.jpg%3F_ex%3D240x240&s=240x240&t=pict"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F18478671%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MSwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B05S4MIsQ")
        ),
        AffiliateItem(
            id: "rakuten-splatoon-raiders",
            title: "スプラトゥーン レイダース",
            priceAndShipping: "　",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=21940603&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F4359%2F4902370554359.jpg%3F_ex%3D240x240&s=240x240&t=picttext"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F18612000%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B08Pjohbm")
        ),
        AffiliateItem(
            id: "rakuten-chiikawa-1",
            title: "ちいかわ　なんか小さくてかわいいやつ（1）",
            priceAndShipping: "1,100円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=20240849&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F3963%2F9784065223963.jpg%3F_ex%3D240x240&s=240x240&t=picttext"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F16589257%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B02icO2XM")
        ),
        AffiliateItem(
            id: "rakuten-it-passport",
            title: "【令和8年度】 いちばんやさしい ITパスポート 絶対合格の教科書＋出る順問題集",
            priceAndShipping: "1,815円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=21788381&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F8207%2F9784815638207_1_2.jpg%3F_ex%3D240x240&s=240x240&t=picttext"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F18432510%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B0goKzUXo")
        ),
        AffiliateItem(
            id: "rakuten-toeic-deru1000",
            title: "TOEIC　L＆Rテスト文法問題でる1000問",
            priceAndShipping: "2,530円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=18620096&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F0833%2F9784866390833_1_6.jpg%3F_ex%3D240x240&s=240x240&t=picttext"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F14999435%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B05lZmsqO")
        ),
        AffiliateItem(
            id: "rakuten-seki-the-rule2",
            title: "関正生のThe Rules 英語長文問題集2入試標準",
            priceAndShipping: "1,320円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=20384382&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F8567%2F9784010348567_1_62.jpg%3F_ex%3D240x240&s=240x240&t=pict"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F16775139%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B00VGtl7N")
        ),
        AffiliateItem(
            id: "rakuten-toeic-official-12",
            title: "公式TOEIC Listening & Reading 問題集 12",
            priceAndShipping: "3,630円",
            imageURL: URL(string: "https://hbb.afl.rakuten.co.jp/hgb/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?me_id=1213310&item_id=21740844&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F3775%2F9784906033775.jpg%3F_ex%3D240x240&s=240x240&t=picttext"),
            rakutenURL: URL(string: "https://hb.afl.rakuten.co.jp/ichiba/56a9c4e7.b6e5be35.56a9c4e8.8024cf62/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F18344234%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MSwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9"),
            amazonURL: URL(string: "https://link.amazon/B09L8lGIJ")
        )
    ]
    
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
    
    static var websiteURL: URL {
        URL(string: "https://junjun.oyajun.com/")!
    }
    
    static var supportURL: URL {
        documentURL(for: "support")
    }

    /// Official Apple Refund Request URL
    static var appleRefundURL: URL {
        URL(string: "https://reportaproblem.apple.com/")!
    }
}

struct AffiliateItem: Identifiable, Sendable {
    let id: String
    let title: String
    let priceAndShipping: String
    let imageURL: URL?
    let rakutenURL: URL?
    let amazonURL: URL?

    init(
        id: String,
        title: String,
        priceAndShipping: String,
        imageURL: URL?,
        rakutenURL: URL?,
        amazonURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.priceAndShipping = priceAndShipping
        self.imageURL = imageURL
        self.rakutenURL = rakutenURL
        self.amazonURL = amazonURL
    }
}
