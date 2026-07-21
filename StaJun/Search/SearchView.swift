import SwiftUI

struct SearchView: View {
    private let pageSize = 20

    @State private var query = ""
    @State private var results: [UserWithFollowStatus] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if results.isEmpty && !query.isEmpty {
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
                                username: user.username,
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

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search Users")
            .onChange(of: query) { _, newValue in
                scheduleSearch(query: newValue)
            }
        }
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            hasMore = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search(query: query)
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
            errorMessage = error.localizedDescription
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
