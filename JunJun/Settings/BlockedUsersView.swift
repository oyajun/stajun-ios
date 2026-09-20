import SwiftUI

struct BlockedUsersView: View {
    @Environment(AppState.self) private var appState
    @Environment(UserStore.self) private var userStore
    @State private var users: [UserWithFollowStatus] = []
    @State private var unblockedUserIds: Set<String> = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var hasMore = false
    @State private var offset = 0
    private let limit = 20

    var body: some View {
        List {
            if isLoading && users.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if users.isEmpty {
                ContentUnavailableView("No Blocked Users", systemImage: "person.crop.circle.badge.xmark")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(users) { user in
                    let liveUser = userStore.user(for: user.id)
                    let isFollowing = liveUser?.isFollowing ?? user.isFollowing
                    let name = liveUser?.name ?? user.name
                    let iconEmoji = liveUser?.iconEmoji ?? user.iconEmoji
                    let iconBackgroundColor = liveUser?.iconBackgroundColor ?? user.iconBackgroundColor
                    let isPro = liveUser?.isPro ?? user.isPro ?? false

                    NavigationLink {
                        UserProfileView(userId: user.id, initialIsBlocked: !unblockedUserIds.contains(user.id))
                    } label: {
                        HStack(spacing: 12) {
                            UserIconView(
                                emoji: iconEmoji,
                                backgroundColor: iconBackgroundColor,
                                size: 44,
                                isStudying: false,
                                isPro: isPro
                            )
                            Text(name)
                                .font(.body)
                            Spacer()
                            if unblockedUserIds.contains(user.id) {
                                Button {
                                    toggleFollow(user: user)
                                } label: {
                                    Text(isFollowing ? "Following" : "Follow")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.bordered)
                                .tint(isFollowing ? .secondary : .accentColor)
                            } else {
                                Button("Unblock") {
                                    Task { await unblockUser(user) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .onAppear {
                        if user.id == users.last?.id {
                            loadMore()
                        }
                    }
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .errorAlert(errorMessage: $errorMessage)
        .refreshable {
            await loadInitial()
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if users.isEmpty {
                await loadInitial()
            }
        }
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        unblockedUserIds.removeAll()
        do {
            let response = try await APIClient.getBlockedUsers(limit: limit, offset: 0)
            userStore.upsert(response.users)
            users = response.users
            hasMore = response.pagination.hasMore
            offset = response.pagination.offset + response.users.count
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        Task {
            isLoadingMore = true
            defer { isLoadingMore = false }
            do {
                let response = try await APIClient.getBlockedUsers(limit: limit, offset: offset)
                userStore.upsert(response.users)
                users.append(contentsOf: response.users)
                hasMore = response.pagination.hasMore
                offset = response.pagination.offset + response.users.count
            } catch {
                // Ignore pagination errors silently
            }
        }
    }

    private func unblockUser(_ user: UserWithFollowStatus) async {
        do {
            try await APIClient.unblockUser(userId: user.id)
            unblockedUserIds.insert(user.id)
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleFollow(user: UserWithFollowStatus) {
        let wasFollowing = userStore.user(for: user.id)?.isFollowing ?? user.isFollowing
        let newValue = !wasFollowing
        userStore.setFollowing(userId: user.id, isFollowing: newValue)
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index].isFollowing = newValue
        }
        Task {
            do {
                if wasFollowing {
                    try await APIClient.unfollow(userId: user.id)
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    appState.requestPushPermissionIfAppropriate()
                }
            } catch {
                userStore.setFollowing(userId: user.id, isFollowing: wasFollowing)
                if let index = users.firstIndex(where: { $0.id == user.id }) {
                    users[index].isFollowing = wasFollowing
                }
                if !error.isCancellation {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environment(AppState())
            .environment(UserStore())
    }
}
