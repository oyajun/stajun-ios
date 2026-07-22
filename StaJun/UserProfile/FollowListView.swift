import SwiftUI

enum FollowListType: String, Identifiable {
    case following
    case followers

    var id: String { rawValue }
}

struct FollowListView: View {
    let userId: String
    var initialTab: FollowListType = .following

    @Environment(AppState.self) private var appState

    @State private var selectedTab: FollowListType
    @State private var followingUsers: [UserWithStudyStatus] = []
    @State private var followersUsers: [UserWithStudyStatus] = []
    @State private var isLoadingFollowing = true
    @State private var isLoadingFollowers = true
    @State private var errorMessage: String?

    init(userId: String, initialTab: FollowListType = .following) {
        self.userId = userId
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentUsers: [UserWithStudyStatus] {
        selectedTab == .following ? followingUsers : followersUsers
    }

    private var isLoadingCurrent: Bool {
        selectedTab == .following ? isLoadingFollowing : isLoadingFollowers
    }

    var body: some View {
        List {
            Picker("", selection: $selectedTab) {
                Text("Following").tag(FollowListType.following)
                Text("Followers").tag(FollowListType.followers)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isLoadingCurrent {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 48)
            } else if currentUsers.isEmpty {
                ContentUnavailableView("No users yet", systemImage: "person.2")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(currentUsers) { user in
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
        .listStyle(.plain)
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFollowing() }
        .task { await loadFollowers() }
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

    private func loadFollowing() async {
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }
        do {
            followingUsers = try await APIClient.getFollowing(userId: userId).users
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFollowers() async {
        isLoadingFollowers = true
        defer { isLoadingFollowers = false }
        do {
            followersUsers = try await APIClient.getFollowers(userId: userId).users
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(user: UserWithStudyStatus) {
        Task {
            do {
                let wasFollowing = user.isFollowing ?? false
                if wasFollowing {
                    try await APIClient.unfollow(userId: user.id)
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                }
                let newValue = !wasFollowing
                if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
                    followingUsers[i].isFollowing = newValue
                }
                if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
                    followersUsers[i].isFollowing = newValue
                }
            } catch {
                // Ignore errors
            }
        }
    }
}

#Preview {
    NavigationStack {
        FollowListView(userId: "preview-user-id")
            .environment(AppState())
    }
}
