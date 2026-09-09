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
    @State private var postToDelete: Post?
    @State private var postToReport: Post?
    @State private var showReportSuccessAlert = false
    @State private var selectedPost: Post? = nil
    @State private var postToEdit: Post? = nil

    @State private var showMuteAlert = false
    @State private var muteAlertTitle: String = ""

    @State private var isBlocked: Bool
    @State private var showBlockConfirmation = false
    @State private var showPaywall = false
    @State private var showEditActivitySheet = false

    init(userId: String, initialIsBlocked: Bool = false) {
        self.userId = userId
        _isBlocked = State(initialValue: initialIsBlocked)
    }

    private var isOwnProfile: Bool {
        appState.currentUser?.id == userId
    }

    private var shareURL: URL? {
        guard let user else { return nil }
        let shortId = String(user.id.prefix(10))
        return URL(string: "https://junjun.oyajun.com/u/\(shortId)")
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
            profileToolbar
        }
        .navigationDestination(item: $followListTab) { tab in
            FollowListView(userId: userId, userName: user?.name, initialTab: tab)
        }
        .navigationDestination(item: $selectedPost) { post in
            postDetailDestination(for: post)
        }
        .sheet(item: $postToEdit) { post in
            EditPostView(post: post) { updated in
                updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showEditActivitySheet) {
            activityEditSheet
        }
        .task {
            await onAppearTask()
        }
        .modifier(
            ProfileAlertsModifier(
                postToDelete: $postToDelete,
                postToReport: $postToReport,
                showReportSuccessAlert: $showReportSuccessAlert,
                showBlockConfirmation: $showBlockConfirmation,
                showMuteAlert: $showMuteAlert,
                muteAlertTitle: muteAlertTitle,
                onDeletePost: { post in Task { await deletePost(post) } },
                onReportPost: { post in Task { await reportPost(post) } },
                onBlock: { Task { await block() } }
            )
        )
    }

    @ViewBuilder
    private func postDetailDestination(for post: Post) -> some View {
        PostDetailView(
            post: post,
            onDelete: {
                posts.removeAll { $0.id == post.id }
                PostsCache.save(posts, scopeKey: "user_\(userId)")
            },
            onToggleLike: { isLiked, count in
                updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
            },
            onUpdate: { updated in
                updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
            }
        )
    }

    @ViewBuilder
    private var activityEditSheet: some View {
        let current = isOwnProfile ? (LocalStudyStore.currentActivity ?? user?.activity) : user?.activity
        ActivityEditSheet(initialActivity: current) { newActivity in
            saveActivity(newActivity)
        }
    }

    private func saveActivity(_ newActivity: String?) {
        Task {
            try? await APIClient.updateStudyActivity(newActivity)
            LocalStudyStore.currentActivity = newActivity
            if var u = user {
                u = UserWithStudyStatus(
                    id: u.id,
                    name: u.name,
                    iconEmoji: u.iconEmoji,
                    iconBackgroundColor: u.iconBackgroundColor,
                    isFollowing: u.isFollowing,
                    muteStudyStartNotification: u.muteStudyStartNotification,
                    isMuted: u.isMuted,
                    isStudying: u.isStudying,
                    studyingSince: u.studyingSince,
                    isPaused: u.isPaused,
                    accumulatedSeconds: u.accumulatedSeconds,
                    isPro: u.isPro,
                    activity: newActivity
                )
                user = u
                UserProfileCache.save(u, userId: userId)
            }
        }
    }

    @ViewBuilder
    private func userContent(_ user: UserWithStudyStatus) -> some View {
        List {
            // Profile header
            profileHeader(user)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: hasProfileBubble(user) ? 14 : 36, leading: 32, bottom: 24, trailing: 32))

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
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
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

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        if let shareURL {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        if !isOwnProfile {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if isBlocked {
                        Button("Unblock", role: .destructive) {
                            Task { await unblock() }
                        }
                    } else {
                        if user?.isFollowing ?? false {
                            Button {
                                Task { await toggleMute() }
                            } label: {
                                Label(
                                    (user?.isMuted ?? false) ? "Unmute Notifications" : "Mute Notifications",
                                    systemImage: (user?.isMuted ?? false) ? "bell" : "bell.slash"
                                )
                            }
                        }

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

    private func isUserStudying(_ user: UserWithStudyStatus) -> Bool {
        guard !isBlocked else { return false }
        return isOwnProfile ? (appState.isStudying || LocalStudyStore.localStartedAt != nil || user.isStudying) : user.isStudying
    }

    private func hasProfileBubble(_ user: UserWithStudyStatus) -> Bool {
        guard isUserStudying(user) else { return false }
        let effectiveActivity = isOwnProfile ? (LocalStudyStore.currentActivity ?? user.activity) : user.activity
        return isOwnProfile || !(effectiveActivity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    @ViewBuilder
    private func profileHeader(_ user: UserWithStudyStatus) -> some View {
        let isUserPro = !isBlocked && ((isOwnProfile && appState.isPro) || (user.isPro ?? false))
        let isStudying = isUserStudying(user)
        let effectiveActivity = isOwnProfile ? (LocalStudyStore.currentActivity ?? user.activity) : user.activity

        VStack(spacing: 12) {
            if hasProfileBubble(user) {
                let userColor = Color(hex: isOwnProfile ? (appState.currentUser?.iconBackgroundColor ?? user.iconBackgroundColor) : user.iconBackgroundColor) ?? .orange
                ProfileActivityBubble(
                    activity: effectiveActivity,
                    isOwnProfile: isOwnProfile,
                    tintColor: userColor,
                    onEdit: {
                        showEditActivitySheet = true
                    }
                )
                .padding(.bottom, 16) // Clear separation from avatar glow (extends ~21.6pt above avatar frame)
            }

            UserIconView(
                emoji: user.iconEmoji,
                backgroundColor: user.iconBackgroundColor,
                size: 80,
                isStudying: isStudying,
                isPro: isUserPro
            )

            VStack(spacing: 6) {
                Text(user.name)
                    .font(.title2.bold())
                    .lineLimit(1)

                if isUserPro {
                    Button {
                        showPaywall = true
                    } label: {
                        ProBadge()
                    }
                    .buttonStyle(.plain)
                }

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
                HStack(spacing: 8) {
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

                    if user.isFollowing ?? false {
                        Button {
                            Task { await toggleMute() }
                        } label: {
                            Image(systemName: (user.isMuted ?? false) ? "bell.slash.fill" : "bell.fill")
                                .font(.body)
                                .frame(width: 44, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint((user.isMuted ?? false) ? .secondary : .accentColor)
                        .accessibilityLabel((user.isMuted ?? false) ? "Unmute Notifications" : "Mute Notifications")
                    }
                }
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
        let base = PostRow(
            post: post,
            onToggleLike: { isLiked, count in
                updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
            },
            onTapDetail: {
                selectedPost = post
            }
        )
            .onAppear {
                if post.id == posts.last?.id { loadMorePosts() }
            }
        if isOwnProfile {
            base
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        postToDelete = post
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        postToEdit = post
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        postToEdit = post
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        postToDelete = post
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            base
                .contextMenu {
                    Button(role: .destructive) {
                        postToReport = post
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
            let mergedActivity = fetched.activity ?? user?.activity
            let merged = UserWithStudyStatus(
                id: fetched.id,
                name: fetched.name,
                iconEmoji: fetched.iconEmoji,
                iconBackgroundColor: fetched.iconBackgroundColor,
                isFollowing: fetched.isFollowing,
                muteStudyStartNotification: fetched.muteStudyStartNotification,
                isMuted: fetched.isMuted,
                isStudying: fetched.isStudying,
                studyingSince: fetched.studyingSince,
                isPaused: fetched.isPaused,
                accumulatedSeconds: fetched.accumulatedSeconds,
                isPro: fetched.isPro,
                activity: mergedActivity
            )
            user = merged
            UserProfileCache.save(merged, userId: userId)
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

    private func onAppearTask() async {
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
                    studyingSince: nil,
                    isPro: appState.isPro,
                    activity: LocalStudyStore.currentActivity
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
                PostsCache.save(posts, scopeKey: "user_\(userId)")
            } catch {
                // Non-fatal
            }
        }
    }

    private func deletePost(_ post: Post) async {
        do {
            try await APIClient.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
            PostsCache.save(posts, scopeKey: "user_\(userId)")
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updatePostLike(id: String, isLiked: Bool, likeCount: Int) {
        if let idx = posts.firstIndex(where: { $0.id == id }) {
            posts[idx].isLiked = isLiked
            posts[idx].likeCount = likeCount
            PostsCache.save(posts, scopeKey: "user_\(userId)")
        }
    }

    private func updatePostContent(id: String, minutes: Int, comment: String?) {
        if let idx = posts.firstIndex(where: { $0.id == id }) {
            let old = posts[idx]
            posts[idx] = Post(
                id: old.id,
                userId: old.userId,
                minutes: minutes,
                comment: comment,
                createdAt: old.createdAt,
                user: old.user,
                likeCount: old.likeCount,
                isLiked: old.isLiked
            )
            PostsCache.save(posts, scopeKey: "user_\(userId)")
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
                user?.muteStudyStartNotification = 0
                user?.isMuted = false
            } else {
                let res = try await APIClient.follow(userId: userId)
                user?.isFollowing = true
                user?.muteStudyStartNotification = res.muteStudyStartNotification ?? 0
                user?.isMuted = res.isMuted ?? ((res.muteStudyStartNotification ?? 0) == 1)
                appState.requestPushPermissionIfAppropriate()
            }
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleMute() async {
        guard let currentUser = user else { return }
        let previousMuted = (currentUser.isMuted == true) || (currentUser.muteStudyStartNotification == 1)
        let previousMode = currentUser.muteStudyStartNotification ?? (previousMuted ? 1 : 0)
        let targetMuted = !previousMuted
        let targetMode = targetMuted ? 1 : 0

        // 楽観的UI更新
        user?.muteStudyStartNotification = targetMode
        user?.isMuted = targetMuted

        do {
            let res = try await APIClient.updateFollowMute(userId: userId, isMuted: targetMuted)
            let isMutedResult = res.isMuted ?? ((res.muteStudyStartNotification ?? targetMode) == 1)
            user?.muteStudyStartNotification = res.muteStudyStartNotification ?? (isMutedResult ? 1 : 0)
            user?.isMuted = isMutedResult
        } catch {
            // エラー時は元の状態にロールバックし、エラーダイアログを表示
            user?.muteStudyStartNotification = previousMode
            user?.isMuted = previousMuted
            muteAlertTitle = targetMuted ? "Could Not Mute" : "Could Not Unmute"
            showMuteAlert = true
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

// MARK: - Profile Alerts ViewModifier

private struct ProfileAlertsModifier: ViewModifier {
    @Binding var postToDelete: Post?
    @Binding var postToReport: Post?
    @Binding var showReportSuccessAlert: Bool
    @Binding var showBlockConfirmation: Bool
    @Binding var showMuteAlert: Bool
    let muteAlertTitle: String
    let onDeletePost: (Post) -> Void
    let onReportPost: (Post) -> Void
    let onBlock: () -> Void

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { postToDelete != nil },
            set: { if !$0 { postToDelete = nil } }
        )
    }

    private var reportBinding: Binding<Bool> {
        Binding(
            get: { postToReport != nil },
            set: { if !$0 { postToReport = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert("Delete Post", isPresented: deleteBinding, presenting: postToDelete) { post in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDeletePost(post)
                }
            } message: { _ in
                Text("Are you sure you want to delete this post?")
            }
            .alert("Report Post", isPresented: reportBinding, presenting: postToReport) { post in
                Button("Cancel", role: .cancel) { }
                Button("Report", role: .destructive) {
                    onReportPost(post)
                }
            } message: { _ in
                Text("Are you sure you want to report this post?")
            }
            .alert("Report Submitted", isPresented: $showReportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you for reporting this post.")
            }
            .alert("Block User", isPresented: $showBlockConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Block", role: .destructive) {
                    onBlock()
                }
            } message: {
                Text("Are you sure you want to block this user?")
            }
            .alert(LocalizedStringKey(muteAlertTitle), isPresented: $showMuteAlert) {
                Button("OK", role: .cancel) { }
            }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .environment(AppState())
    }
}
