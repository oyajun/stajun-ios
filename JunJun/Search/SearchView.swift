import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
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
                                NavigationLink {
                                    UserProfileView(userId: user.id)
                                } label: {
                                    UserRow(
                                        iconEmoji: user.iconEmoji,
                                        iconBackgroundColor: user.iconBackgroundColor,
                                        name: user.name,
                                        isStudying: user.isStudying,
                                        isFollowing: user.isFollowing ?? false,
                                        onFollowToggle: { toggleFollowRecommended(user: user) }
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
                                NavigationLink {
                                    UserProfileView(userId: user.id)
                                } label: {
                                    UserRow(
                                        iconEmoji: user.iconEmoji,
                                        iconBackgroundColor: user.iconBackgroundColor,
                                        name: user.name,
                                        isStudying: user.isStudying ?? false,
                                        isFollowing: user.isFollowing,
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


                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search Users")
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
                results.append(contentsOf: response.users)
                hasMore = response.pagination.hasMore
            } catch {
                // Ignore errors on pagination; user can retry by scrolling again
            }
        }
    }

    private func toggleFollow(user: UserWithFollowStatus) {
        guard let index = results.firstIndex(where: { $0.id == user.id }) else { return }
        Task {
            do {
                if user.isFollowing {
                    try await APIClient.unfollow(userId: user.id)
                    results[index].isFollowing = false
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    results[index].isFollowing = true
                    appState.requestPushPermissionIfAppropriate()
                }
            } catch {
                // Ignore errors (no UI rollback needed)
            }
        }
    }

    private func toggleFollowRecommended(user: UserWithStudyStatus) {
        guard let index = recommendedUsers.firstIndex(where: { $0.id == user.id }) else { return }
        let currentlyFollowing = user.isFollowing ?? false
        Task {
            do {
                if currentlyFollowing {
                    try await APIClient.unfollow(userId: user.id)
                    recommendedUsers[index].isFollowing = false
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    recommendedUsers[index].isFollowing = true
                    appState.requestPushPermissionIfAppropriate()
                }
            } catch {
                // Ignore errors (no UI rollback needed)
            }
        }
    }
}

#Preview {
    SearchView()
}
