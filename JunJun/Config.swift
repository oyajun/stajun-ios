import Foundation

enum Config {
    #if DEBUG
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    //static let baseURL = URL(string: "http://192.168.128.105:3000")!
    #else
    static let baseURL = URL(string: "https://junjun.oyajun.com")!
    #endif

    /// Home feed polling interval (seconds)
    static let feedPollingInterval: TimeInterval = 90

    /// Short-term memory cache TTL for polling requests to prevent redundant API calls (seconds)
    static let pollCacheTTL: TimeInterval = 5
    
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
    
    /// Google AdMob Native Ad Unit ID
    static let adMobNativeUnitID: String = "ca-app-pub-5564838687301652/6734410178"
    
    /// Keywords passed to AdMob to prioritize student, educational, brand, entertainment, and part-time job ads
    static let adMobKeywords: [String] = [
        "Apple", "Mac", "iPad", "MacBook", "学割", "学生", "勉強", "受験", "大学", "高校生", "大学生", "資格", "英語", "education", "student", "study",
        "Hulu", "hulu", "マイナビ", "マイナビバイト", "バイト", "アルバイト", "就活", "インターン"
    ]
    
    /// Amazon Prime Student promotion URL
    static let primeStudentURL: URL = URL(string: "https://www.amazon.co.jp/b?node=2410972051&tag=junjun0962-22")!
    
    /// HelloTalk promotions (afb affiliate)
    static let helloTalkAdItems: [PromotionBannerItem] = [
        PromotionBannerItem(
            id: "hellotalk-250-1",
            linkURL: URL(string: "https://t.afi-b.com/visit.php?a=B16836j-O537309I&p=j993573G")!,
            imageURL: URL(string: "https://www.afi-b.com/upload_image/16836-1788696055-3.png?1789563686")!,
            width: 250,
            height: 250
        ),
        PromotionBannerItem(
            id: "hellotalk-300-1",
            linkURL: URL(string: "https://t.afi-b.com/visit.php?a=B16836j-q537316W&p=j993573G")!,
            imageURL: URL(string: "https://www.afi-b.com/upload_image/16836-1790680455-3.jpg?1789563686")!,
            width: 300,
            height: 250
        ),
        PromotionBannerItem(
            id: "hellotalk-300-2",
            linkURL: URL(string: "https://t.afi-b.com/visit.php?a=B16836j-k537307x&p=j993573G")!,
            imageURL: URL(string: "https://www.afi-b.com/upload_image/16836-1791266055-3.png?1789563686")!,
            width: 300,
            height: 250
        ),
        PromotionBannerItem(
            id: "hellotalk-300-3",
            linkURL: URL(string: "https://t.afi-b.com/visit.php?a=B16836j-A537315O&p=j993573G")!,
            imageURL: URL(string: "https://www.afi-b.com/upload_image/16836-1786821155-3.png?1789563686")!,
            width: 300,
            height: 250
        ),
        PromotionBannerItem(
            id: "hellotalk-250-2",
            linkURL: URL(string: "https://t.afi-b.com/visit.php?a=B16836j-h537311B&p=j993573G")!,
            imageURL: URL(string: "https://www.afi-b.com/upload_image/16836-1795117555-3.png?1789563686")!,
            width: 250,
            height: 250
        )
    ]

    /// コミック.jp promotion (afb affiliate)
    static let comicJpAdItem = PromotionBannerItem(
        id: "comic-jp-300",
        linkURL: URL(string: "https://t.afi-b.com/visit.php?a=j12573O-C410463s&p=j993573G")!,
        imageURL: URL(string: "https://www.afi-b.com/upload_image/12573-1618495483-3.png")!,
        width: 300,
        height: 250
    )

    /// teamLabBody Pro promotion (afb affiliate)
    static let teamLabBodyProAdItem = PromotionBannerItem(
        id: "teamlabbody-pro-300",
        linkURL: URL(string: "https://t.afi-b.com/visit.php?a=m16765P-z536509Q&p=j993573G")!,
        imageURL: URL(string: "https://www.afi-b.com/upload_image/16765-1794466659-3.png")!,
        width: 300,
        height: 250
    )

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
    static let expirationDate: Date? = ISO8601DateFormatter().date(from: "2026-11-30T23:59:59Z")
    
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

    /// Specified Commercial Transactions Act (Commercial Disclosure) URL
    static var tokushohoURL: URL {
        documentURL(for: "tokushoho")
    }
}

struct PromotionBannerItem: Identifiable, Sendable {
    let id: String
    let linkURL: URL
    let imageURL: URL
    let width: CGFloat
    let height: CGFloat
}

typealias HelloTalkAdItem = PromotionBannerItem

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
