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
    /// Called when the post body (outside author/like button) is tapped to open details.
    var onTapDetail: (() -> Void)? = nil
    /// Whether to show the bottom divider.
    var showDivider: Bool = true

    @Environment(UserStore.self) private var userStore

    private let iconSize: CGFloat = 44

    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var isToggling = false

    private var liveUser: UserProfile {
        if let stored = userStore.user(for: post.userId) {
            return UserProfile(
                id: stored.id,
                name: stored.name,
                iconEmoji: stored.iconEmoji,
                iconBackgroundColor: stored.iconBackgroundColor,
                isPro: stored.isPro
            )
        }
        return post.user
    }

    init(
        post: Post,
        onTapAuthor: (() -> Void)? = nil,
        onToggleLike: ((_ isLiked: Bool, _ likeCount: Int) -> Void)? = nil,
        onTapDetail: (() -> Void)? = nil,
        showDivider: Bool = true
    ) {
        self.post = post
        self.onTapAuthor = onTapAuthor
        self.onToggleLike = onToggleLike
        self.onTapDetail = onTapDetail
        self.showDivider = showDivider
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
                .dateTime.locale(locale).month(.defaultDigits).day().hour().minute()
            )
        }

        return post.createdAt.formatted(
            .dateTime.locale(locale).year().month(.defaultDigits).day().hour().minute()
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                authorLink {
                    UserIconView(
                        emoji: liveUser.iconEmoji,
                        backgroundColor: liveUser.iconBackgroundColor,
                        size: iconSize,
                        isPro: liveUser.isPro ?? false
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        authorLink {
                            Text(liveUser.name)
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
            .contentShape(Rectangle())
            .onTapGesture {
                onTapDetail?()
            }

            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }

    private var likeButton: some View {
        Button(action: toggleLike) {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .red : .secondary)
                    .scaleEffect(heartScale)
                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.subheadline)
                        .foregroundColor(isLiked ? .red : .secondary)
                        .contentTransition(.numericText())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike post" : "Like post")
        .accessibilityValue(likeCount > 0 ? "\(likeCount) likes" : "No likes")
    }

    private func toggleLike() {
        guard !isToggling else { return }
        isToggling = true

        let nextIsLiked = !isLiked
        let nextCount = isLiked ? max(0, likeCount - 1) : likeCount + 1

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.15)) {
            isLiked = nextIsLiked
            likeCount = nextCount
            if nextIsLiked {
                heartScale = 1.3
            }
        }
        if nextIsLiked {
            withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
                heartScale = 1.0
            }
        }

        onToggleLike?(nextIsLiked, nextCount)

        Task {
            defer { isToggling = false }
            do {
                if nextIsLiked {
                    _ = try await APIClient.likePost(id: post.id)
                } else {
                    _ = try await APIClient.unlikePost(id: post.id)
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isLiked = !nextIsLiked
                        likeCount = nextIsLiked ? max(0, likeCount - 1) : likeCount + 1
                    }
                    onToggleLike?(!nextIsLiked, likeCount)
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
        .environment(UserStore())
    }
}
