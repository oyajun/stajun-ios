import SwiftUI

/// A single study-time post row (author, study time, comment, relative time).
/// Only the author's icon and name link to their profile; the row height
/// adapts to whether a comment is present.
struct PostRow: View {
    let post: Post
    /// Called when the author's icon or name is tapped. When nil, they are not tappable.
    var onTapAuthor: (() -> Void)? = nil

    private let iconSize: CGFloat = 44
    /// UserIconView reserves `size * 1.4` for the studying glow halo. Posts don't
    /// show that glow, so trim the halo inset to align the icon's circle with the name.
    private var iconGlowInset: CGFloat { iconSize * 0.2 }

    private var durationText: String {
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
        HStack(alignment: .top, spacing: 12) {
            authorLink {
                UserIconView(
                    emoji: post.user.iconEmoji,
                    backgroundColor: post.user.iconBackgroundColor,
                    size: iconSize
                )
            }
            .padding(.vertical, -iconGlowInset)

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

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(durationText)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)

                if let comment = post.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 10)
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
            user: UserProfile(id: "u1", name: "hanako", iconEmoji: "🐣", iconBackgroundColor: "#B3E5FC")
        ))
    }
}
