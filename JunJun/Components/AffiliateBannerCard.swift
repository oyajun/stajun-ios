import SwiftUI

/// 楽天アフィリエイト用のキャッシュマネージャー（商品選定と画像のキャッシュ）
@MainActor
final class AffiliateCache {
    static let shared = AffiliateCache()
    private var itemCache: [String: AffiliateItem] = [:]
    private var usedItemIDs: Set<String> = []
    private var lastAssignedID: String?
    private let imageCache = NSCache<NSURL, UIImage>()

    private init() {
        // バックグラウンドでアフィリエイト画像を事前キャッシュ
        Task { [weak self] in
            await self?.prefetchImages()
        }
    }

    func item(for key: String, from items: [AffiliateItem]) -> AffiliateItem? {
        if let cached = itemCache[key] {
            return cached
        }
        guard !items.isEmpty else { return nil }

        // まだ割り当てられていない商品候補から選択
        var candidates = items.filter { !usedItemIDs.contains($0.id) }
        if candidates.isEmpty {
            // 全商品が出尽くした場合は使用済みリストをリセット
            usedItemIDs.removeAll()
            // 直前に割り当てた商品と連続しないように除外（2商品以上ある場合）
            if items.count > 1, let lastID = lastAssignedID {
                candidates = items.filter { $0.id != lastID }
            } else {
                candidates = items
            }
        }

        guard let picked = candidates.randomElement() ?? items.randomElement() else { return nil }
        itemCache[key] = picked
        usedItemIDs.insert(picked.id)
        lastAssignedID = picked.id
        return picked
    }

    func image(for url: URL) -> UIImage? {
        imageCache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        imageCache.setObject(image, forKey: url as NSURL)
    }

    func prefetchImages() async {
        for item in Config.affiliateItems {
            guard let url = item.imageURL, image(for: url) == nil else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    setImage(uiImage, for: url)
                }
            } catch {
                // エラー時はスキップ
            }
        }
    }
}

/// キャッシュ付き画像表示ビュー（スクロールで戻っても再読み込みなし）
private struct CachedAffiliateImage: View {
    let url: URL?
    @State private var image: UIImage?

    init(url: URL?) {
        self.url = url
        if let url, let cached = AffiliateCache.shared.image(for: url) {
            _image = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.white
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
            }
        }
        .frame(width: 82, height: 82)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            guard let url, image == nil else { return }
            if let cached = AffiliateCache.shared.image(for: url) {
                self.image = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    AffiliateCache.shared.setImage(uiImage, for: url)
                    self.image = uiImage
                }
            } catch {
                // エラー時はフォールバック
            }
        }
    }
}

/// 楽天アフィリエイト用の横長バナー広告コンポーネント
struct AffiliateBannerCard: View {
    let cacheKey: String?
    let items: [AffiliateItem]
    private let item: AffiliateItem?
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

    init(cacheKey: String? = nil, items: [AffiliateItem] = Config.affiliateItems) {
        self.cacheKey = cacheKey
        self.items = items
        if let key = cacheKey {
            self.item = AffiliateCache.shared.item(for: key, from: items)
        } else {
            self.item = items.randomElement()
        }
    }

    var body: some View {
        if Config.isAffiliateAdVisible && !appState.isPro, let item {
            HStack(alignment: .center, spacing: 12) {
                // キャッシュ付き商品画像
                CachedAffiliateImage(url: item.imageURL)

                // 商品情報
                VStack(alignment: .leading, spacing: 6) {
                    // タイトル + 右上の×ボタン＆広告バッジ（縦並び）
                    HStack(alignment: .top, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 4)
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            AdCloseButton()

                            Text(LocalizedStringKey("Ad"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.0, green: 0.68, blue: 0.85), in: Capsule())
                                .fixedSize()
                        }
                    }

                    // 値段
                    if !item.priceAndShipping.isEmpty {
                        Text(item.priceAndShipping)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // 楽天で購入 + Amazonで購入 ボタン
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)

                        // 楽天で購入ボタン
                        if let rakutenURL = item.rakutenURL {
                            Button {
                                openURL(rakutenURL)
                            } label: {
                                Text("楽天で購入")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.75, green: 0.0, blue: 0.0), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // Amazonで購入ボタン
                        if let amazonURL = item.amazonURL {
                            Button {
                                openURL(amazonURL)
                            } label: {
                                Text("Amazonで購入")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.95, green: 0.55, blue: 0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
