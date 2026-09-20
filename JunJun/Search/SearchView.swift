import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(UserStore.self) private var userStore
    private let pageSize = 20

    @State private var query = ""
    @State private var results: [UserWithFollowStatus] = []
    @State private var recommendedUsers: [UserWithStudyStatus] = []
    @State private var isLoading = false
    @State private var isLoadingRecommended = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // おすすめユーザーセクション
                    Section {
                        if isLoadingRecommended {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if recommendedUsers.isEmpty {
                            ContentUnavailableView(
                                "No Recommendations Available",
                                systemImage: "person.2.slash"
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(recommendedUsers) { user in
                                let liveUser = userStore.user(for: user.id) ?? user
                                NavigationLink {
                                    UserProfileView(userId: user.id)
                                } label: {
                                    UserRow(
                                        iconEmoji: liveUser.iconEmoji,
                                        iconBackgroundColor: liveUser.iconBackgroundColor,
                                        name: liveUser.name,
                                        isStudying: liveUser.isStudying,
                                        isPro: user.id == appState.currentUser?.id ? appState.isPro : (liveUser.isPro ?? false),
                                        isFollowing: liveUser.isFollowing ?? false,
                                        onFollowToggle: { toggleFollowRecommended(user: liveUser) }
                                    )
                                }
                            }
                        }
                    } header: {
                        Text("Recommended Users")
                    }
                } else {
                    // 検索結果セクション
                    Section {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if results.isEmpty {
                            ContentUnavailableView.search(text: query)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(results) { user in
                                let liveUser = userStore.user(for: user.id)
                                let isFollowing = liveUser?.isFollowing ?? user.isFollowing
                                let isStudying = liveUser?.isStudying ?? (user.isStudying ?? false)
                                let name = liveUser?.name ?? user.name
                                let iconEmoji = liveUser?.iconEmoji ?? user.iconEmoji
                                let iconBackgroundColor = liveUser?.iconBackgroundColor ?? user.iconBackgroundColor
                                let isPro = user.id == appState.currentUser?.id ? appState.isPro : (liveUser?.isPro ?? user.isPro ?? false)

                                NavigationLink {
                                    UserProfileView(userId: user.id)
                                } label: {
                                    UserRow(
                                        iconEmoji: iconEmoji,
                                        iconBackgroundColor: iconBackgroundColor,
                                        name: name,
                                        isStudying: isStudying,
                                        isPro: isPro,
                                        isFollowing: isFollowing,
                                        onFollowToggle: { toggleFollow(user: user) }
                                    )
                                }
                                .onAppear {
                                    if user.id == results.last?.id {
                                        loadMoreIfNeeded()
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
                            }
                        }
                    } header: {
                        Text("Search Results")
                    }
                }
            }
            .navigationTitle("Search")
            .errorAlert(errorMessage: $errorMessage)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Users")
            .textInputAutocapitalization(.never)
            .task {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recommendedUsers.isEmpty {
                    await loadRecommendedUsers()
                }
            }
            .onChange(of: query) { _, newValue in
                scheduleSearch(query: newValue)
            }
            .refreshable {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await loadRecommendedUsers()
                } else {
                    await search(query: query)
                }
            }
        }
    }

    private func loadRecommendedUsers() async {
        isLoadingRecommended = true
        errorMessage = nil
        defer { isLoadingRecommended = false }
        do {
            let response = try await APIClient.getRecommendedUsers()
            userStore.upsert(response.users)
            recommendedUsers = response.users
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            hasMore = false
            Task {
                await loadRecommendedUsers()
            }
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search(query: trimmed)
        }
    }

    private func search(query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.searchUsers(query: query, limit: pageSize, offset: 0)
            userStore.upsert(response.users)
            results = response.users
            hasMore = response.pagination.hasMore
        } catch APIError.notFound {
            results = []
            hasMore = false
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        let currentQuery = query
        Task {
            isLoadingMore = true
            defer { isLoadingMore = false }
            do {
                let response = try await APIClient.searchUsers(
                    query: currentQuery,
                    limit: pageSize,
                    offset: results.count
                )
                userStore.upsert(response.users)
                let existingIds = Set(results.map(\.id))
                let uniqueUsers = response.users.filter { !existingIds.contains($0.id) }
                results.append(contentsOf: uniqueUsers)
                hasMore = response.pagination.hasMore
            } catch {
                // Ignore errors on pagination; user can retry by scrolling again
            }
        }
    }

    private func performFollowToggle(userId: String, wasFollowing: Bool, onRollback: @escaping () -> Void) {
        Task {
            do {
                if wasFollowing {
                    try await APIClient.unfollow(userId: userId)
                } else {
                    _ = try await APIClient.follow(userId: userId)
                    appState.requestPushPermissionIfAppropriate()
                }
            } catch {
                userStore.setFollowing(userId: userId, isFollowing: wasFollowing)
                onRollback()
            }
        }
    }

    private func toggleFollow(user: UserWithFollowStatus) {
        let wasFollowing = userStore.user(for: user.id)?.isFollowing ?? user.isFollowing
        let nextFollowing = !wasFollowing
        userStore.setFollowing(userId: user.id, isFollowing: nextFollowing)
        if let index = results.firstIndex(where: { $0.id == user.id }) {
            results[index].isFollowing = nextFollowing
        }
        performFollowToggle(userId: user.id, wasFollowing: wasFollowing) {
            if let currentIndex = results.firstIndex(where: { $0.id == user.id }) {
                results[currentIndex].isFollowing = wasFollowing
            }
        }
    }

    private func toggleFollowRecommended(user: UserWithStudyStatus) {
        let wasFollowing = userStore.user(for: user.id)?.isFollowing ?? (user.isFollowing ?? false)
        let nextFollowing = !wasFollowing
        userStore.setFollowing(userId: user.id, isFollowing: nextFollowing)
        if let index = recommendedUsers.firstIndex(where: { $0.id == user.id }) {
            recommendedUsers[index].isFollowing = nextFollowing
        }
        performFollowToggle(userId: user.id, wasFollowing: wasFollowing) {
            if let currentIndex = recommendedUsers.firstIndex(where: { $0.id == user.id }) {
                recommendedUsers[currentIndex].isFollowing = wasFollowing
            }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppState())
        .environment(UserStore())
}
