import SwiftUI

/// アイコン・ユーザー名・フォローボタンを並べた共有行コンポーネント。
/// onFollowToggle が nil のときはフォローボタンを非表示にする（自分自身の行など）。
struct UserRow: View {
    let iconEmoji: String
    let iconBackgroundColor: String
    let name: String
    let isFollowing: Bool
    let onFollowToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            UserIconView(
                emoji: iconEmoji,
                backgroundColor: iconBackgroundColor,
                size: 44
            )
            Text(name)
                .font(.body)
            Spacer()
            if let onFollowToggle {
                Button {
                    onFollowToggle()
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(isFollowing ? .secondary : .accentColor)
            }
        }
    }
}
