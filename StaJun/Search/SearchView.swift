import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [UserWithFollowStatus] = []
    @State private var isLoading = false
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
                            SearchUserRow(user: user, onFollowToggle: { toggleFollow(user: user) })
                        }
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
            let response = try await APIClient.searchUsers(query: query)
            results = response.users
        } catch APIError.notFound {
            results = []
        } catch {
            errorMessage = error.localizedDescription
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

// MARK: - Search User Row

struct SearchUserRow: View {
    let user: UserWithFollowStatus
    let onFollowToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            UserIconView(
                emoji: user.iconEmoji,
                backgroundColor: user.iconBackgroundColor,
                size: 44
            )
            Text(user.username)
                .font(.body)
            Spacer()
            Button {
                onFollowToggle()
            } label: {
                Text(user.isFollowing ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(user.isFollowing ? .secondary : .accentColor)
        }
    }
}

#Preview {
    SearchView()
}
