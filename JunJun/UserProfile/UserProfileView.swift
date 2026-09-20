import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AppState.self) private var appState
    @Environment(UserStore.self) private var userStore

    @State private var user: UserWithStudyStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFollowLoading = false

    @State private var followListTab: FollowListType?

    @State private var posts: [Post] = []
    @State private var postsCursor: String?
    @State private var isLoadingPosts = false
    @State private var hasLoadedPosts = false
    @State private var hasFetchedInitialPosts = false
    @State private var postToDelete: Post?
    @State private var postToReport: Post?
    @State private var showReportSuccessAlert = false
    @State private var selectedPost: Post? = nil
    @State private var postToEdit: Post? = nil

    @State private var showMuteAlert = false
    @State private var muteAlertTitle: LocalizedStringResource = ""

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

    private var effectiveUser: UserWithStudyStatus? {
        userStore.user(for: userId) ?? user
    }

    private var shareURL: URL? {
        guard let effectiveUser else { return nil }
        let shortId = String(effectiveUser.id.prefix(10))
        return URL(string: "https://junjun.oyajun.com/u/\(shortId)")
    }

    var body: some View {
        Group {
            if isLoading && effectiveUser == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let effectiveUser {
                userContent(effectiveUser)
            } else {
                ContentUnavailableView("User Not Found", systemImage: "person.slash")
            }
        }
        .navigationTitle(effectiveUser?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            profileToolbar
        }
        .navigationDestination(item: $followListTab) { tab in
            FollowListView(userId: userId, userName: effectiveUser?.name, initialTab: tab)
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
        let current = isOwnProfile ? (LocalStudyStore.currentActivity ?? effectiveUser?.activity) : effectiveUser?.activity
        ActivityEditSheet(initialActivity: current) { newActivity in
            saveActivity(newActivity)
        }
    }

    private func saveActivity(_ newActivity: String?) {
        Task {
            try? await APIClient.updateStudyActivity(newActivity)
            LocalStudyStore.currentActivity = newActivity
            let current = effectiveUser
            let isStudying = isOwnProfile ? (appState.isStudying || LocalStudyStore.localStartedAt != nil || (current?.isStudying ?? false)) : (current?.isStudying ?? false)
            let studyingSince = isOwnProfile ? (LocalStudyStore.localStartedAt ?? current?.studyingSince) : current?.studyingSince
            let isPaused = isOwnProfile ? (appState.isPaused || LocalStudyStore.isPaused) : (current?.isPaused ?? false)
            let accumulatedSeconds = isOwnProfile ? Int(LocalStudyStore.accumulatedSeconds) : current?.accumulatedSeconds

            userStore.setStudyStatus(
                userId: userId,
                isStudying: isStudying,
                studyingSince: studyingSince,
                isPaused: isPaused,
                accumulatedSeconds: accumulatedSeconds,
                activity: newActivity
            )

            if var u = user {
                u = UserWithStudyStatus(
                    id: u.id,
                    name: u.name,
                    iconEmoji: u.iconEmoji,
                    iconBackgroundColor: u.iconBackgroundColor,
                    isFollowing: u.isFollowing,
                    muteStudyStartNotification: u.muteStudyStartNotification,
                    isMuted: u.isMuted,
                    isStudying: isStudying,
                    studyingSince: studyingSince,
                    isPaused: isPaused,
                    accumulatedSeconds: accumulatedSeconds,
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
                        if effectiveUser?.isFollowing ?? false {
                            Button {
                                Task { await toggleMute() }
                            } label: {
                                Label(
                                    (effectiveUser?.isMuted ?? false) ? "Unmute Notifications" : "Mute Notifications",
                                    systemImage: (effectiveUser?.isMuted ?? false) ? "bell" : "bell.slash"
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

    private func isUserPaused(_ user: UserWithStudyStatus) -> Bool {
        guard !isBlocked else { return false }
        if isOwnProfile, LocalStudyStore.localStartedAt != nil {
            return appState.isPaused || LocalStudyStore.isPaused
        }
        return user.isPaused ?? false
    }

    private func hasValidStudyTimer(user: UserWithStudyStatus) -> Bool {
        if isOwnProfile {
            return LocalStudyStore.localStartedAt != nil || user.studyingSince != nil
        } else {
            return user.studyingSince != nil || user.accumulatedSeconds != nil
        }
    }

    private func currentElapsedSeconds(user: UserWithStudyStatus, now: Date) -> TimeInterval {
        if isOwnProfile, LocalStudyStore.localStartedAt != nil {
            return LocalStudyStore.totalElapsedSeconds(at: now)
        }
        if user.isPaused == true {
            return Double(user.accumulatedSeconds ?? 0)
        }
        if let since = user.studyingSince {
            return max(0, now.timeIntervalSince(since))
        }
        return 0
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

                if !isBlocked, isStudying, hasValidStudyTimer(user: user) {
                    let isPaused = isUserPaused(user)
                    if isPaused {
                        let elapsed = currentElapsedSeconds(user: user, now: .now)
                        Text(HomeTimeFormatter.formatElapsed(seconds: elapsed))
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = currentElapsedSeconds(user: user, now: context.date)
                            Text(HomeTimeFormatter.formatElapsed(seconds: elapsed))
                                .font(.title3.monospacedDigit().bold())
                                .foregroundStyle(.orange)
                        }
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
                        .accessibilityLabel((user.isMuted ?? false) ? LocalizedStringKey("Unmute Notifications") : LocalizedStringKey("Mute Notifications"))
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
                        Label("Report", systemImage: "flag")
                    }
                }
        }
    }

    // MARK: - Actions

    private func load() async {
        if effectiveUser == nil {
            isLoading = true
        }
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await APIClient.getUser(id: userId)
            let currentActivity = effectiveUser?.activity
            let mergedActivity = isOwnProfile ? (LocalStudyStore.currentActivity ?? fetched.activity ?? currentActivity) : (fetched.activity ?? currentActivity)
            let isStudying = isOwnProfile ? (appState.isStudying || LocalStudyStore.localStartedAt != nil || fetched.isStudying) : fetched.isStudying
            let studyingSince = isOwnProfile ? (LocalStudyStore.localStartedAt ?? fetched.studyingSince) : fetched.studyingSince
            let isPaused = isOwnProfile ? (appState.isPaused || LocalStudyStore.isPaused) : fetched.isPaused
            let accumulatedSeconds = isOwnProfile ? Int(LocalStudyStore.accumulatedSeconds) : fetched.accumulatedSeconds
            let merged = UserWithStudyStatus(
                id: fetched.id,
                name: fetched.name,
                iconEmoji: fetched.iconEmoji,
                iconBackgroundColor: fetched.iconBackgroundColor,
                isFollowing: fetched.isFollowing,
                isBlocked: fetched.isBlocked,
                muteStudyStartNotification: fetched.muteStudyStartNotification,
                isMuted: fetched.isMuted,
                isStudying: isStudying,
                studyingSince: studyingSince,
                isPaused: isPaused,
                accumulatedSeconds: accumulatedSeconds,
                isPro: fetched.isPro,
                activity: mergedActivity
            )
            user = merged
            userStore.upsert(merged)
            isBlocked = fetched.isBlocked ?? false
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func onAppearTask() async {
        if user == nil {
            if let memoryUser = userStore.user(for: userId) {
                user = memoryUser
                isLoading = false
            } else if let cached = UserProfileCache.load(userId: userId) {
                user = cached
                userStore.upsert(cached)
                isLoading = false
            } else if isOwnProfile, let me = appState.currentUser {
                let initial = UserWithStudyStatus(
                    id: me.id,
                    name: me.name,
                    iconEmoji: me.iconEmoji,
                    iconBackgroundColor: me.iconBackgroundColor,
                    isFollowing: nil,
                    isStudying: appState.isStudying || LocalStudyStore.localStartedAt != nil,
                    studyingSince: LocalStudyStore.localStartedAt,
                    isPaused: appState.isPaused || LocalStudyStore.isPaused,
                    accumulatedSeconds: Int(LocalStudyStore.accumulatedSeconds),
                    isPro: appState.isPro,
                    activity: LocalStudyStore.currentActivity
                )
                user = initial
                userStore.upsert(initial)
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
        if !isBlocked && !hasFetchedInitialPosts {
            hasFetchedInitialPosts = true
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
                let existingIds = Set(posts.map(\.id))
                let uniquePosts = response.posts.filter { !existingIds.contains($0.id) }
                posts.append(contentsOf: uniquePosts)
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
        guard let currentUser = effectiveUser else { return }
        let wasFollowing = currentUser.isFollowing ?? false
        let nextFollowing = !wasFollowing

        userStore.setFollowing(userId: userId, isFollowing: nextFollowing)
        user?.isFollowing = nextFollowing

        isFollowLoading = true
        defer { isFollowLoading = false }
        do {
            if wasFollowing {
                try await APIClient.unfollow(userId: userId)
                userStore.setFollowing(userId: userId, isFollowing: false, isMuted: false, muteNotification: 0)
                user?.isFollowing = false
                user?.muteStudyStartNotification = 0
                user?.isMuted = false
            } else {
                let res = try await APIClient.follow(userId: userId)
                let muteNotif = res.muteStudyStartNotification ?? 0
                let isMuted = res.isMuted ?? (muteNotif == 1)
                userStore.setFollowing(userId: userId, isFollowing: true, isMuted: isMuted, muteNotification: muteNotif)
                user?.isFollowing = true
                user?.muteStudyStartNotification = muteNotif
                user?.isMuted = isMuted
                appState.requestPushPermissionIfAppropriate()
            }
        } catch {
            userStore.setFollowing(userId: userId, isFollowing: wasFollowing)
            user?.isFollowing = wasFollowing
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleMute() async {
        guard let currentUser = effectiveUser else { return }
        let previousMuted = (currentUser.isMuted == true) || (currentUser.muteStudyStartNotification == 1)
        let previousMode = currentUser.muteStudyStartNotification ?? (previousMuted ? 1 : 0)
        let targetMuted = !previousMuted
        let targetMode = targetMuted ? 1 : 0

        // 楽観的UI更新
        userStore.setMuted(userId: userId, isMuted: targetMuted, muteNotification: targetMode)
        user?.muteStudyStartNotification = targetMode
        user?.isMuted = targetMuted

        do {
            let res = try await APIClient.updateFollowMute(userId: userId, isMuted: targetMuted)
            let isMutedResult = res.isMuted ?? ((res.muteStudyStartNotification ?? targetMode) == 1)
            let muteNotifResult = res.muteStudyStartNotification ?? (isMutedResult ? 1 : 0)
            userStore.setMuted(userId: userId, isMuted: isMutedResult, muteNotification: muteNotifResult)
            user?.muteStudyStartNotification = muteNotifResult
            user?.isMuted = isMutedResult
        } catch {
            // エラー時は元の状態にロールバック
            userStore.setMuted(userId: userId, isMuted: previousMuted, muteNotification: previousMode)
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
            userStore.setFollowing(userId: userId, isFollowing: false)
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
            hasFetchedInitialPosts = true
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
    let muteAlertTitle: LocalizedStringResource
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
            .alert(muteAlertTitle, isPresented: $showMuteAlert) {
                Button("OK", role: .cancel) { }
            }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .environment(AppState())
            .environment(UserStore())
    }
}
