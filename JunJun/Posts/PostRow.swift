import SwiftUI

/// A single study-time post row (author, study time, comment, relative time, like button).
/// Only the author's icon and name link to their profile; the row height
/// adapts to whether a comment is present.
struct PostRow: View {
    let post: Post
    /// Called when the author's icon or name is tapped. When nil, they are not tappable.
    var onTapAuthor: (() -> Void)? = nil
    /// Called when like status or count changes (for updating parent cache).
    var onToggleLike: ((_ isLiked: Bool, _ likeCount: Int) -> Void)? = nil

    private let iconSize: CGFloat = 44

    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var isToggling = false

    init(
        post: Post,
        onTapAuthor: (() -> Void)? = nil,
        onToggleLike: ((_ isLiked: Bool, _ likeCount: Int) -> Void)? = nil
    ) {
        self.post = post
        self.onTapAuthor = onTapAuthor
        self.onToggleLike = onToggleLike
        _isLiked = State(initialValue: post.isLiked)
        _likeCount = State(initialValue: post.likeCount)
    }

    private var durationText: LocalizedStringKey {
        let h = post.minutes / 60
        let m = post.minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private var postedAtText: String {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let locale = Locale.autoupdatingCurrent

        if calendar.isDate(post.createdAt, inSameDayAs: now) {
            return post.createdAt.formatted(
                .dateTime.locale(locale).hour().minute()
            )
        }

        let createdYear = calendar.component(.year, from: post.createdAt)
        let currentYear = calendar.component(.year, from: now)
        if createdYear == currentYear {
            return post.createdAt.formatted(
                .dateTime.locale(locale).month().day().hour().minute()
            )
        }

        return post.createdAt.formatted(
            .dateTime.locale(locale).year().month().day().hour().minute()
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                authorLink {
                    UserIconView(
                        emoji: post.user.iconEmoji,
                        backgroundColor: post.user.iconBackgroundColor,
                        size: iconSize,
                        isPro: post.user.isPro ?? false
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        authorLink {
                            Text(post.user.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(postedAtText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let comment = post.comment, !comment.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(durationText)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)

                        HStack(alignment: .bottom) {
                            Text(comment)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            likeButton
                        }
                    } else {
                        HStack(alignment: .center) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(durationText)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)

                            Spacer()

                            likeButton
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 16)
        }
        .onChange(of: post.isLiked) { _, newValue in
            isLiked = newValue
        }
        .onChange(of: post.likeCount) { _, newValue in
            likeCount = newValue
        }
    }

    // MARK: - Like Button

    @ViewBuilder
    private var likeButton: some View {
        Button {
            toggleLike()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .foregroundStyle(isLiked ? Color.pink : Color.secondary)
                    .scaleEffect(heartScale)

                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isLiked ? Color.pink : Color.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
    }

    private func toggleLike() {
        guard !isToggling else { return }
        isToggling = true

        let wasLiked = isLiked
        let prevCount = likeCount
        let nextLiked = !wasLiked
        let nextCount = nextLiked ? prevCount + 1 : max(0, prevCount - 1)

        // 楽観的UIの即時更新
        isLiked = nextLiked
        likeCount = nextCount
        onToggleLike?(nextLiked, nextCount)

        // 触覚フィードバック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // アニメーション
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            heartScale = nextLiked ? 1.35 : 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
        }

        Task {
            defer { isToggling = false }
            do {
                let res = if wasLiked {
                    try await APIClient.unlikePost(id: post.id)
                } else {
                    try await APIClient.likePost(id: post.id)
                }
                // サーバー最新値との差分があれば同期
                if likeCount != res.likeCount || isLiked != res.isLiked {
                    isLiked = res.isLiked
                    likeCount = res.likeCount
                    onToggleLike?(res.isLiked, res.likeCount)
                }
            } catch {
                // エラー時はサイレントにロールバック
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLiked = wasLiked
                    likeCount = prevCount
                    onToggleLike?(wasLiked, prevCount)
                }
            }
        }
    }

    /// Makes content tappable (navigating to the author) when a handler is provided.
    /// Uses a Button rather than a NavigationLink so multiple inline tap targets
    /// don't turn the whole List row into a link (which breaks the layout).
    @ViewBuilder
    private func authorLink<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let onTapAuthor {
            Button(action: onTapAuthor) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

#Preview {
    List {
        PostRow(post: Post(
            id: "1",
            userId: "u1",
            minutes: 95,
            comment: "英文法おわり",
            createdAt: .now.addingTimeInterval(-3600),
            user: UserProfile(id: "u1", name: "hanako", iconEmoji: "🐣", iconBackgroundColor: "#B3E5FC", isAnonymous: false),
            likeCount: 3,
            isLiked: true
        ))
    }
}
