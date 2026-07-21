import SwiftUI

enum FollowListType {
    case followers
    case following

    var title: String {
        switch self {
        case .followers: return "Followers"
        case .following: return "Following"
        }
    }
}

struct FollowListView: View {
    let userId: String
    let listType: FollowListType

    @Environment(AppState.self) private var appState

    @State private var users: [UserWithStudyStatus] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                ContentUnavailableView("No users yet", systemImage: "person.2")
            } else {
                List(users) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                        UserRow(
                            iconEmoji: user.iconEmoji,
                            iconBackgroundColor: user.iconBackgroundColor,
                            username: user.username,
                            isFollowing: user.isFollowing ?? false,
                            onFollowToggle: user.id == appState.currentUser?.id
                                ? nil
                                : { toggleFollow(user: user) }
                        )
                    }
                }
            }
        }
        .navigationTitle(listType.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch listType {
            case .followers:
                users = try await APIClient.getFollowers(userId: userId).users
            case .following:
                users = try await APIClient.getFollowing(userId: userId).users
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(user: UserWithStudyStatus) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        Task {
            do {
                if user.isFollowing ?? false {
                    try await APIClient.unfollow(userId: user.id)
                    users[index].isFollowing = false
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    users[index].isFollowing = true
                }
            } catch {
                // Ignore errors
            }
        }
    }
}

#Preview {
    NavigationStack {
        FollowListView(userId: "preview-user-id", listType: .followers)
            .environment(AppState())
    }
}
