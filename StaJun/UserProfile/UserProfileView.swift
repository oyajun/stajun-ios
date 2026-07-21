import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AppState.self) private var appState

    @State private var user: UserWithStudyStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFollowLoading = false

    // Posts by this user (public)
    @State private var posts: [Post] = []
    @State private var postsCursor: String?
    @State private var isLoadingPosts = false

    private var isOwnProfile: Bool {
        appState.currentUser?.id == userId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let user {
                userContent(user)
            } else {
                ContentUnavailableView("User Not Found", systemImage: "person.slash")
            }
        }
        .navigationTitle(user?.username ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            await loadPosts()
        }
    }

    @ViewBuilder
    private func userContent(_ user: UserWithStudyStatus) -> some View {
        List {
            // Icon and status
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        UserIconView(
                            emoji: user.iconEmoji,
                            backgroundColor: user.iconBackgroundColor,
                            size: 80,
                            isStudying: user.isStudying
                        )
                        Text(user.username)
                            .font(.title2.bold())

                        if user.isStudying {
                            Label("Studying", systemImage: "book.fill")
                                .font(.body)
                                .foregroundStyle(.orange)
                            if let since = user.studyingSince {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(studyingDurationString(since: since, now: context.date))
                                        .font(.title3.monospacedDigit().bold())
                                        .foregroundStyle(.orange)
                                }
                            }
                        } else {
                            Text("Not Studying")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Followers / Following
            Section {
                NavigationLink(destination: FollowListView(userId: userId, listType: .followers)) {
                    Text("Followers")
                }
                NavigationLink(destination: FollowListView(userId: userId, listType: .following)) {
                    Text("Following")
                }
            }

            // Follow button (for other users)
            if !isOwnProfile {
                Section {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack {
                            Spacer()
                            if isFollowLoading {
                                ProgressView()
                            } else {
                                Text(user.isFollowing ?? false ? "Following" : "Follow")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .tint(user.isFollowing ?? false ? .secondary : .accentColor)
                    .disabled(isFollowLoading)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.subheadline)
                }
            }

            // Posts by this user
            Section("Posts") {
                if posts.isEmpty {
                    Text(isLoadingPosts ? "Loading…" : "No posts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(posts) { post in
                        postRow(post)
                    }
                }
            }
        }
    }

    /// A post row on the profile. Own posts get a long-press menu to delete.
    @ViewBuilder
    private func postRow(_ post: Post) -> some View {
        let base = PostRow(post: post)
            .onAppear {
                if post.id == posts.last?.id { loadMorePosts() }
            }
        if isOwnProfile {
            base
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await deletePost(post) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await deletePost(post) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            base
        }
    }

    private func studyingDurationString(since: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(since)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            user = try await APIClient.getUser(id: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let response = try await APIClient.getUserPosts(userId: userId)
            posts = response.posts
            postsCursor = response.nextCursor
        } catch {
            // Non-fatal: profile still shows without posts.
        }
    }

    private func loadMorePosts() {
        guard let cursor = postsCursor, !isLoadingPosts else { return }
        Task {
            isLoadingPosts = true
            defer { isLoadingPosts = false }
            do {
                let response = try await APIClient.getUserPosts(userId: userId, cursor: cursor)
                posts.append(contentsOf: response.posts)
                postsCursor = response.nextCursor
            } catch {
                // Ignore pagination errors.
            }
        }
    }

    private func deletePost(_ post: Post) async {
        do {
            try await APIClient.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow() async {
        guard let currentUser = user else { return }
        isFollowLoading = true
        defer { isFollowLoading = false }
        do {
            if currentUser.isFollowing ?? false {
                try await APIClient.unfollow(userId: userId)
                user?.isFollowing = false
            } else {
                _ = try await APIClient.follow(userId: userId)
                user?.isFollowing = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .environment(AppState())
    }
}
