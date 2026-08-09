import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AppState.self) private var appState

    @State private var user: UserWithStudyStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFollowLoading = false

    @State private var followListTab: FollowListType?

    @State private var posts: [Post] = []
    @State private var postsCursor: String?
    @State private var isLoadingPosts = false
    @State private var hasLoadedPosts = false
    @State private var showReportSuccessAlert = false

    @State private var isBlocked: Bool
    @State private var showBlockConfirmation = false

    init(userId: String, initialIsBlocked: Bool = false) {
        self.userId = userId
        _isBlocked = State(initialValue: initialIsBlocked)
    }

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
        .navigationTitle(user?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwnProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isBlocked {
                            Button("Unblock", role: .destructive) {
                                Task { await unblock() }
                            }
                        } else {
                            Button("Block", role: .destructive) {
                                showBlockConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .navigationDestination(item: $followListTab) { tab in
            FollowListView(userId: userId, initialTab: tab)
        }
        .task {
            if user == nil {
                if let cached = UserProfileCache.load(userId: userId) {
                    user = cached
                    isLoading = false
                } else if isOwnProfile, let me = appState.currentUser {
                    user = UserWithStudyStatus(
                        id: me.id,
                        name: me.name,
                        iconEmoji: me.iconEmoji,
                        iconBackgroundColor: me.iconBackgroundColor,
                        isFollowing: nil,
                        isStudying: appState.isStudying,
                        studyingSince: nil
                    )
                    isLoading = false
                }
            }
            if !isBlocked && posts.isEmpty {
                let cachedPosts = PostsCache.load(scopeKey: "user_\(userId)")
                if !cachedPosts.isEmpty {
                    posts = cachedPosts
                    hasLoadedPosts = true
                }
            }
            await load()
            if !isBlocked {
                await loadPosts()
            }
        }
        .alert("Report Submitted", isPresented: $showReportSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thank you for reporting this post.")
        }
        .alert("Block User", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                Task { await block() }
            }
        } message: {
            Text("Are you sure you want to block this user?")
        }
    }

    @ViewBuilder
    private func userContent(_ user: UserWithStudyStatus) -> some View {
        List {
            // Profile header
            profileHeader(user)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))

            // Posts
            if isBlocked {
                VStack(spacing: 16) {
                    ContentUnavailableView("Blocked", systemImage: "person.crop.circle.badge.xmark", description: Text("You have blocked this user."))
                    Button("Unblock") {
                        Task { await unblock() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 48)
            } else if !hasLoadedPosts && posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 48)
            } else if posts.isEmpty {
                ContentUnavailableView("No Posts Yet", systemImage: "square.and.pencil")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(posts) { post in
                    postRow(post)
                        .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await load()
            if !isBlocked {
                await loadPosts()
            }
        }
    }

    @ViewBuilder
    private func profileHeader(_ user: UserWithStudyStatus) -> some View {
        VStack(spacing: 16) {
            UserIconView(
                emoji: user.iconEmoji,
                backgroundColor: user.iconBackgroundColor,
                size: 80,
                isStudying: isBlocked ? false : user.isStudying
            )

            VStack(spacing: 6) {
                Text(user.name)
                    .font(.title2.bold())

                if !isBlocked, user.isStudying, let since = user.studyingSince {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(studyingDurationString(since: since, now: context.date))
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(.orange)
                    }
                }
            }

            if !isBlocked {
                HStack(spacing: 16) {
                    Button("Following Users") { followListTab = .following }
                        .buttonStyle(.bordered)
                        .font(.subheadline.weight(.medium))

                    Button("Followers") { followListTab = .followers }
                        .buttonStyle(.bordered)
                        .font(.subheadline.weight(.medium))
                }
            }

            if !isOwnProfile && !isBlocked {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Group {
                        if isFollowLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(user.isFollowing ?? false ? "Following" : "Follow")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(user.isFollowing ?? false ? .secondary : .accentColor)
                .disabled(isFollowLoading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func postRow(_ post: Post) -> some View {
        let base = PostRow(post: post)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
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
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await reportPost(post) }
                    } label: {
                        Label("Report", systemImage: "exclamationmark.bubble")
                    }
                }
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
        if user == nil {
            isLoading = true
        }
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await APIClient.getUser(id: userId)
            user = fetched
            UserProfileCache.save(fetched, userId: userId)
            let blockedResp = try? await APIClient.getBlockedUsers(limit: 50, offset: 0)
            if let resp = blockedResp, resp.users.contains(where: { $0.id == userId }) {
                isBlocked = true
            }
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadPosts() async {
        isLoadingPosts = true
        defer {
            isLoadingPosts = false
            hasLoadedPosts = true
        }
        do {
            let response = try await APIClient.getUserPosts(userId: userId)
            posts = response.posts
            postsCursor = response.nextCursor
            PostsCache.save(response.posts, scopeKey: "user_\(userId)")
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
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reportPost(_ post: Post) async {
        do {
            try await APIClient.reportPost(id: post.id)
            showReportSuccessAlert = true
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
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
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func block() async {
        do {
            try await APIClient.blockUser(userId: userId)
            isBlocked = true
            user?.isFollowing = false
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func unblock() async {
        do {
            try await APIClient.unblockUser(userId: userId)
            isBlocked = false
            await loadPosts()
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .environment(AppState())
    }
}
