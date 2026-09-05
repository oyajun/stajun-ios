import SwiftUI

/// タイムライン広告スロットの種類
enum TimelineSlotAdType {
    case adMob
    case primeStudent
    case affiliate
}

/// タイムライン広告スロットの出し分けマネージャー
/// ルール:
/// 1. Admob or Prime(1/5)
/// 2. Admob or Prime（1でPrimeが出ていなければPrime、出ていればAdmob）
/// 3. 楽天/Amazon (Affiliate)
/// 4. Admob
/// それ以降（5つ目〜）: 楽天/Amazon と AdMob の繰り返し
@MainActor
final class TimelineAdSlotManager {
    static let shared = TimelineAdSlotManager()
    private var slotDecisions: [Int: TimelineSlotAdType] = [:]

    private init() {}

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

    private func computeAdType(for slotIndex: Int) -> TimelineSlotAdType {
        switch slotIndex {
        case 0:
            // 1つ目: 1/5 (20%) の確率で Prime Student、残り4/5で AdMob
            let isPrime = Int.random(in: 0..<5) == 0
            return isPrime ? .primeStudent : .adMob

        case 1:
            // 2つ目: 1つ目 (slot 0) で Prime が出ていなければ Prime を出す
            let prevType = adType(for: 0)
            if prevType == .primeStudent {
                return .adMob
            } else {
                return .primeStudent
            }

        default:
            // 3つ目以降（slotIndex >= 2）: 楽天/Amazon と AdMob の繰り返し
            // slot 2: 楽天/Amazon, slot 3: AdMob, slot 4: 楽天/Amazon, slot 5: AdMob...
            if slotIndex % 2 == 0 {
                return .affiliate
            } else {
                return .adMob
            }
        }
    }
}

/// Custom banner view for Amazon Prime Student (Full-width, 250pt height).
struct PrimeStudentBannerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

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
                        Text("Amazon Prime Student")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        // 2. 特典一覧
                        Text("送料無料　Prime Video　容量無制限の写真ストレージ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 16)

                        // 3. 価格（「学生なら」で改行し、金額を大きく表示）
                        VStack(spacing: 3) {
                            Text("学生なら")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black)

                            Text("\(Text("年額 ").font(.system(size: 17, weight: .bold)))\(Text("2,950円").font(.system(size: 28, weight: .black)))\(Text(" または 月額 ").font(.system(size: 17, weight: .bold)))\(Text("300円").font(.system(size: 28, weight: .black)))\(Text(" !!").font(.system(size: 24, weight: .black)))")
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 16)
                        }

                        // 4. 初回特典バッジ
                        Text("年払いなら初回半年間無料")
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
