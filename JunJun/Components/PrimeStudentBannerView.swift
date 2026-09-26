import SwiftUI

/// タイムライン広告スロットの種類
enum TimelineSlotAdType {
    case adMobNative
    case adMobBanner
    case primeStudent
    case helloTalk
    case comicJp
    case teamLabBody
    case affiliate
}

/// タイムライン広告スロットの出し分けマネージャー
/// ルール:
/// 1. 普通のバナー広告（AdMob Banner）
/// 2. ネイティブバナー 4/5 の確率、アフィリエイトのバナー（特別プロモーション4種均等） 1/5 の確率
/// 3. 2つ目で出なかったタイプ（2つ目がネイティブならアフィリエイト、2つ目がアフィリエイトならネイティブ）
/// 4つ目以降（slotIndex >= 3）: ネイティブバナーとバナーを 1/2 の確率で出し分け
@MainActor
final class TimelineAdSlotManager {
    static let shared = TimelineAdSlotManager()
    private var slotDecisions: [Int: TimelineSlotAdType] = [:]
    private var specialPromotionDecisions: [String: TimelineSlotAdType] = [:]

    private var specialPromotionTypes: [TimelineSlotAdType] {
        [.primeStudent, .helloTalk, .comicJp, .teamLabBody]
    }

    private init() {}

    /// Clears cached slot decisions so that slot ad types can be re-evaluated on pull-to-refresh.
    func reset() {
        slotDecisions.removeAll()
        specialPromotionDecisions.removeAll()
    }

    /// スロットインデックス（0, 1, 2...）に応じた広告種別を返す。
    /// スクロール時のちらつきを防ぐため、結果はキャッシュされる。
    func adType(for slotIndex: Int) -> TimelineSlotAdType {
        if let cached = slotDecisions[slotIndex] {
            return cached
        }

        let type = computeAdType(for: slotIndex)
        slotDecisions[slotIndex] = type
        return type
    }

    func specialPromotionType(for key: String?) -> TimelineSlotAdType {
        if let key, let cached = specialPromotionDecisions[key] {
            return cached
        }
        let picked = randomSpecialPromotion()
        if let key {
            specialPromotionDecisions[key] = picked
        }
        return picked
    }

    private func randomSpecialPromotion() -> TimelineSlotAdType {
        specialPromotionTypes.randomElement() ?? .primeStudent
    }

    private func randomAdMobType() -> TimelineSlotAdType {
        Bool.random() ? .adMobNative : .adMobBanner
    }

    private func computeAdType(for slotIndex: Int) -> TimelineSlotAdType {
        switch slotIndex {
        case 0:
            // 1つ目: 普通のバナー広告（ネイティブじゃないやつ）
            return .adMobBanner

        case 1:
            // 2つ目: ネイティブバナー4/5の確率、1/5でアフィリエイトのバナー（特別プロモーション4種均等）
            let isSpecial = Int.random(in: 0..<5) == 0
            return isSpecial ? randomSpecialPromotion() : .adMobNative

        case 2:
            // 3つ目: 2つ目で出なかったタイプ（2つ目が特別プロモーションならネイティブ、ネイティブなら特別プロモーション）
            let slot1Type = adType(for: 1)
            if specialPromotionTypes.contains(slot1Type) {
                return .adMobNative
            } else {
                return randomSpecialPromotion()
            }

        default:
            // 4つ目以降（slotIndex >= 3）: ネイティブバナーとバナーを 1/2
            return randomAdMobType()
        }
    }
}

/// Custom banner view for Amazon Prime Student (Full-width, 250pt height).
struct PrimeStudentBannerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

    private var priceAttributedString: AttributedString {
        var string = AttributedString()

        var year = AttributedString("年額 ")
        year.font = .system(size: 17, weight: .bold)
        string.append(year)

        var yearPrice = AttributedString("2,950円")
        yearPrice.font = .system(size: 28, weight: .black)
        string.append(yearPrice)

        var monthly = AttributedString(" または 月額 ")
        monthly.font = .system(size: 17, weight: .bold)
        string.append(monthly)

        var monthlyPrice = AttributedString("300円")
        monthlyPrice.font = .system(size: 28, weight: .black)
        string.append(monthlyPrice)

        var exclamation = AttributedString(" !!")
        exclamation.font = .system(size: 24, weight: .black)
        string.append(exclamation)

        return string
    }

    var body: some View {
        if Config.showAds && !appState.isPro {
            ZStack(alignment: .topTrailing) {
                // Main clickable banner
                Button {
                    openURL(Config.primeStudentURL)
                } label: {
                    VStack(spacing: 10) {
                        Spacer(minLength: 0)

                        // 1. タイトル
                        Text(verbatim: "Amazon Prime Student")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        // 2. 特典一覧
                        Text(verbatim: "送料無料　Prime Video　容量無制限の写真ストレージ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 16)

                        // 3. 価格（「学生なら」で改行し、金額を大きく表示）
                        VStack(spacing: 3) {
                            Text(verbatim: "学生なら")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black)

                            Text(priceAttributedString)
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 16)
                        }

                        // 4. 初回特典バッジ
                        Text(verbatim: "年払いなら初回半年間無料")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.95), in: Capsule())

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(Color(red: 25 / 255.0, green: 152 / 255.0, blue: 255 / 255.0))
                }
                .buttonStyle(.plain)

                // Close button inside top-right corner
                AdCloseButton()
                    .padding(12)

                // Ad badge inside bottom-right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AdBadge()
                            .padding(12)
                    }
                }
                .frame(height: 250)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
        }
    }
}

/// Custom image banner view for promotional affiliate ads (HelloTalk, コミック.jp, teamLabBody Pro, etc.)
struct CustomPromotionBannerView: View {
    let item: PromotionBannerItem?
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState
    @State private var bannerImage: UIImage?

    init(item: PromotionBannerItem?) {
        self.item = item
        if let item, let cached = AffiliateCache.shared.image(for: item.imageURL) {
            _bannerImage = State(initialValue: cached)
        }
    }

    var body: some View {
        if Config.showAds && !appState.isPro, let item {
            HStack(alignment: .bottom, spacing: 6) {
                Button {
                    openURL(item.linkURL)
                } label: {
                    ZStack {
                        Color(uiColor: .secondarySystemBackground)
                        if let bannerImage {
                            Image(uiImage: bannerImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(width: item.width, height: item.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                VStack(alignment: .trailing, spacing: 6) {
                    AdCloseButton()
                    Spacer()
                    AdBadge()
                }
                .frame(height: 250)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 250)
            .task(id: item.id) {
                if bannerImage == nil {
                    if let cached = AffiliateCache.shared.image(for: item.imageURL) {
                        bannerImage = cached
                    } else {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: item.imageURL)
                            if let uiImage = UIImage(data: data) {
                                AffiliateCache.shared.setImage(uiImage, for: item.imageURL)
                                bannerImage = uiImage
                            }
                        } catch {
                            // エラー時はスキップ
                        }
                    }
                }
            }
        }
    }
}

/// 特別プロモーション（Prime Student / HelloTalk / コミック.jp / teamLabBody Pro）の出し分けバナー
struct SpecialPromotionBannerCard: View {
    let cacheKey: String?
    private let promotionType: TimelineSlotAdType

    init(cacheKey: String? = nil) {
        self.cacheKey = cacheKey
        self.promotionType = TimelineAdSlotManager.shared.specialPromotionType(for: cacheKey)
    }

    var body: some View {
        switch promotionType {
        case .primeStudent:
            PrimeStudentBannerView()
        case .helloTalk:
            CustomPromotionBannerView(item: AffiliateCache.shared.helloTalkItem(for: cacheKey))
        case .comicJp:
            CustomPromotionBannerView(item: Config.comicJpAdItem)
        case .teamLabBody:
            CustomPromotionBannerView(item: Config.teamLabBodyProAdItem)
        default:
            PrimeStudentBannerView()
        }
    }
}
