import SwiftUI
import Combine
import UIKit

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    // Navigation
    @State private var path = NavigationPath()

    // Study status — initialise from local store so the border appears immediately on launch
    @State private var isStudying = LocalStudyStore.localStartedAt != nil
    @State private var isPaused = LocalStudyStore.isPaused
    @State private var studyStartedAt: Date?
    @State private var studyActionLoading = false
    @State private var studyError: String?

    // Feed (following users study status)
    @State private var feedUsers: [UserWithStudyStatus] = []
    @State private var feedError: String?
    @State private var isRefreshingStudyState = false
    @State private var isLoadingFeed = false
    @State private var hasLoadedFeed = false

    // Timeline posts (Following & Mine completely separated)
    private let pageSize = 20
    private let firstAdIndex = 1
    private let adInterval = 7
    @State private var followingPosts: [Post] = []
    @State private var followingNextCursor: String?
    @State private var isLoadingFollowingPosts = false
    @State private var isLoadingMoreFollowingPosts = false
    @State private var hasLoadedFollowingPosts = false

    @State private var myPosts: [Post] = []
    @State private var myNextCursor: String?
    @State private var isLoadingMyPosts = false
    @State private var isLoadingMoreMyPosts = false
    @State private var hasLoadedMyPosts = false

    @State private var postsError: String?
    @State private var postScope: PostScope = .following
    @State private var showCompose = false
    @State private var postToEdit: Post?
    @State private var postToDelete: Post?
    @State private var postToReport: Post?
    @State private var showReportSuccessAlert = false
    @State private var showInviteFriendsAlert = false

    private var currentPosts: [Post] {
        switch postScope {
        case .following: return followingPosts
        case .mine:      return myPosts
        }
    }

    private var hasLoadedCurrentPosts: Bool {
        switch postScope {
        case .following: return hasLoadedFollowingPosts
        case .mine:      return hasLoadedMyPosts
        }
    }

    private var isLoadingMoreCurrentPosts: Bool {
        switch postScope {
        case .following: return isLoadingMoreFollowingPosts
        case .mine:      return isLoadingMoreMyPosts
        }
    }

    // Timer (elapsed time display)
    @State private var now = Date()

    // Network reachability
    @State private var network = NetworkMonitor.shared

    // Post composer (shown after stopping a study session)
    @State private var showComposePost = false
    @State private var composeInitialMinutes = 0

    private enum PostScope: Hashable {
        case following, mine
        var title: String {
            switch self {
            case .following: return "Following"
            case .mine: return "Mine"
            }
        }
        var cacheKey: String {
            switch self {
            case .following: return "following"
            case .mine: return "mine"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Offline banner
                if !network.isOnline {
                    offlineBanner
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 0, trailing: 32))
                }

                // Study start/stop card
                studyCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 20, leading: 32, bottom: 0, trailing: 32))

                // Following users (loads independently)
                followingContent
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                // Scope picker + compose button (inline)
                HStack {
                    Picker("Scope", selection: $postScope) {
                        Text(LocalizedStringKey(PostScope.following.title)).tag(PostScope.following)
                        Text(LocalizedStringKey(PostScope.mine.title)).tag(PostScope.mine)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                    }
                    .buttonStyle(.glass)
                    .padding(.leading, 4)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 32))

                // Posts: loading / empty states
                if !hasLoadedCurrentPosts && currentPosts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 48)
                } else if currentPosts.isEmpty {
                    emptyPostsSection
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                } else {
                    // Post rows (swipe-to-delete + long-press context menu)
                    ForEach(Array(currentPosts.enumerated()), id: \.element.id) { index, post in
                        timelinePostRow(post)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())

                        if Config.showAds && !appState.isPro && index >= firstAdIndex && (index - firstAdIndex) % adInterval == 0 {
                            timelineAdRow(for: index)
                        }
                    }
                }

                if isLoadingMoreCurrentPosts {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 16)
                }
            }
            .listStyle(.plain)
            .animation(.easeInOut, value: network.isOnline)
            .refreshable {
                await pollHome(force: true)
                await loadFollowingPosts()
                await loadMyPosts()
            }
            .task {
                // Show last-known feed and posts immediately (works offline)
                if feedUsers.isEmpty {
                    let cachedFeed = FeedCache.load()
                    if !cachedFeed.isEmpty {
                        feedUsers = cachedFeed
                        hasLoadedFeed = true
                    }
                }
                if followingPosts.isEmpty {
                    let cached = PostsCache.load(scopeKey: "following")
                    if !cached.isEmpty {
                        followingPosts = cached
                        hasLoadedFollowingPosts = true
                    }
                }
                if myPosts.isEmpty {
                    let cached = PostsCache.load(scopeKey: "mine")
                    if !cached.isEmpty {
                        myPosts = cached
                        hasLoadedMyPosts = true
                    }
                }
                await pollHome()
                await loadFollowingPosts()
                await loadMyPosts()
                await startPolling()
            }
            .onChange(of: isStudying) { _, newValue in
                appState.isStudying = newValue
            }
            .onChange(of: network.isOnline) { _, online in
                if online {
                    Task { await pollHome() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await pollHome()
                    }
                }
            }
            .onReceive(
                Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            ) { _ in
                now = Date()
            }
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .navigationDestination(for: Post.self) { post in
                PostDetailView(
                    post: post,
                    onDelete: {
                        myPosts.removeAll { $0.id == post.id }
                        followingPosts.removeAll { $0.id == post.id }
                        PostsCache.save(myPosts, scopeKey: "mine")
                        PostsCache.save(followingPosts, scopeKey: "following")
                    },
                    onToggleLike: { isLiked, count in
                        updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
                    },
                    onUpdate: { updated in
                        updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
                    }
                )
            }
            .sheet(item: $postToEdit) { post in
                EditPostView(post: post) { updated in
                    updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
                }
            }
            .sheet(isPresented: $showComposePost) {
                ComposePostView(initialMinutes: composeInitialMinutes) { newPost in
                    prependPost(newPost)
                    Task {
                        await loadFollowingPosts()
                        await loadMyPosts()
                        await loadFeed()
                    }
                    handlePostMilestone()
                }
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView { newPost in
                    prependPost(newPost)
                    Task {
                        await loadFollowingPosts()
                        await loadMyPosts()
                        await loadFeed()
                    }
                    handlePostMilestone()
                }
            }
            .alert("Delete Post", isPresented: Binding(
                get: { postToDelete != nil },
                set: { if !$0 { postToDelete = nil } }
            ), presenting: postToDelete) { post in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deletePost(post) }
                }
            } message: { _ in
                Text("Are you sure you want to delete this post?")
            }
            .alert("Report Post", isPresented: Binding(
                get: { postToReport != nil },
                set: { if !$0 { postToReport = nil } }
            ), presenting: postToReport) { post in
                Button("Cancel", role: .cancel) { }
                Button("Report", role: .destructive) {
                    Task { await reportPost(post) }
                }
            } message: { _ in
                Text("Are you sure you want to report this post?")
            }
            .alert("Report Submitted", isPresented: $showReportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you for reporting this post.")
            }
            .alert("Invite Your Friends!", isPresented: $showInviteFriendsAlert) {
                Button("Share Your Profile") {
                    shareMyProfile()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Have your friends install the app and follow each other.\nYou'll be able to see when and what they are studying!")
            }
            .overlay(alignment: .bottom) {
                if let postsError, !currentPosts.isEmpty {
                    Text(postsError)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
    }

    // MARK: - Study Card

    @ViewBuilder
    private var studyCard: some View {
        HStack(alignment: .bottom, spacing: 40) {
            // Left: own icon + name (fluffy animation tied to local isStudying)
            Button {
                if let userId = appState.currentUser?.id {
                    path.append(userId)
                }
            } label: {
                VStack(spacing: 0) {
                    UserIconView(
                        emoji: appState.currentUser?.iconEmoji ?? "📚",
                        backgroundColor: appState.currentUser?.iconBackgroundColor ?? "#FFD54F",
                        size: 52,
                        isStudying: isStudying,
                        isPro: appState.isPro
                    )
                    Text(appState.currentUser?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.top, 14)
                }
            }
            .buttonStyle(.plain)

            // Right: timer + button
            VStack(spacing: 12) {
                HStack {
                    Text(isStudying ? formatElapsed(seconds: LocalStudyStore.totalElapsedSeconds(at: now)) : "--:--")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(isStudying ? (isPaused ? Color.secondary : Color.orange) : Color.secondary)
                    Spacer()
                    Text(isStudying ? (isPaused ? LocalizedStringKey("Paused") : LocalizedStringKey("Studying")) : LocalizedStringKey("Not Studying"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !isStudying {
                    // Not studying: [ Start ] (Full width, accent, text only)
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        Task { await startStudying() }
                    } label: {
                        Group {
                            if studyActionLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(LocalizedStringKey("Start"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                    .disabled(studyActionLoading)
                } else if isPaused {
                    // Paused: [ Resume ] (Full width, accent, text only)
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        Task { await resumeStudying() }
                    } label: {
                        Group {
                            if studyActionLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(LocalizedStringKey("Resume"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                    .disabled(studyActionLoading)
                } else {
                    // Studying active: [ pause.fill ] (Neutral, circular) + [ Stop ] (Red, text only)
                    HStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            Task { await pauseStudying() }
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.subheadline.bold())
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(LocalizedStringKey("Pause"))
                        .disabled(studyActionLoading)

                        Button {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            stopStudying()
                        } label: {
                            Group {
                                if studyActionLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(LocalizedStringKey("Stop"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                        .disabled(studyActionLoading)
                    }
                    .background {
                        StudyingButtonGlow(
                            backgroundColor: appState.currentUser?.iconBackgroundColor ?? "#FFD54F",
                            isPro: appState.isPro
                        )
                        .opacity(1)
                        .animation(.easeInOut(duration: 0.3), value: isStudying)
                    }
                }

                if let studyError {
                    Text(studyError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("You're offline")
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Following Content

    @ViewBuilder
    private var followingContent: some View {
        if !hasLoadedFeed && feedUsers.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 117)
        } else if feedUsers.isEmpty {
            emptyFeedSection
        } else {
            followingSection
        }
    }

    // MARK: - Following Section

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(feedUsers) { user in
                        NavigationLink(value: user.id) {
                            VStack(spacing: 0) {
                                UserIconView(
                                    emoji: user.iconEmoji,
                                    backgroundColor: user.iconBackgroundColor,
                                    size: 52,
                                    isStudying: user.isStudying,
                                    isPro: user.isPro ?? false
                                )
                                Text(user.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.top, 8)
                                if user.isStudying {
                                    if user.isPaused == true {
                                        let acc = Double(user.accumulatedSeconds ?? 0)
                                        Text(formatElapsed(seconds: acc))
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 2)
                                    } else if let since = user.studyingSince {
                                        Text(elapsedString(from: since, to: now))
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .foregroundStyle(.orange)
                                            .padding(.top, 2)
                                    } else {
                                        Text(" ")
                                            .font(.caption2)
                                            .padding(.top, 2)
                                    }
                                } else {
                                    Text(" ")
                                        .font(.caption2)
                                        .padding(.top, 2)
                                }
                            }
                            .frame(width: 74)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 42)
                .padding(.bottom, 10)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Empty Feed

    private var emptyFeedSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Following Users")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Find people to follow in the Search tab")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 117)
    }

    // MARK: - Empty Posts

    private var emptyPostsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Posts Yet")
                .font(.body)
                .foregroundStyle(.secondary)
            Text(postScope == .following
                 ? "Posts from you and people you follow will appear here."
                 : "Your posts will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Timeline Post Row

    @ViewBuilder
    private func timelinePostRow(_ post: Post) -> some View {
        let base = PostRow(
            post: post,
            onTapAuthor: { path.append(post.userId) },
            onToggleLike: { isLiked, count in
                updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
            },
            onTapDetail: {
                path.append(post)
            }
        )
            .onAppear {
                if post.id == currentPosts.last?.id { loadMoreCurrentPosts() }
            }
        if post.userId == appState.currentUser?.id {
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

    // MARK: - Timeline Ad Row

    @ViewBuilder
    private func timelineAdRow(for index: Int) -> some View {
        let slotIndex = (index - firstAdIndex) / adInterval
        VStack(spacing: 0) {
            if Config.isJapanRegion {
                switch TimelineAdSlotManager.shared.adType(for: slotIndex) {
                case .primeStudent:
                    PrimeStudentBannerView()
                case .adMob:
                    AdBannerCard(cacheKey: "timeline-admob-\(index)")
                case .affiliate:
                    AffiliateBannerCard(cacheKey: "timeline-affiliate-\(index)")
                }
            } else {
                AdBannerCard(cacheKey: "timeline-admob-\(index)")
            }
            Divider()
                .padding(.horizontal, 16)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Study Actions

    /// Reconcile study status received from server against local state.
    private func applyStudyStatus(_ status: MyStudyStatus) async {
        if let local = LocalStudyStore.localStartedAt {
            // Studying locally: the local timer stays the measured one either way.
            isStudying = true
            isPaused = LocalStudyStore.isPaused
            studyStartedAt = local

            if status.isStudying {
                // Already shared; nothing to announce.
                LocalStudyStore.startedOffline = false
            } else if LocalStudyStore.startedOffline {
                // Began offline and was never announced. Publish it now.
                do {
                    try await APIClient.startStudy()
                    LocalStudyStore.startedOffline = false
                } catch { }
            } else {
                // The server knew about this session and it's gone: ended on another device.
                LocalStudyStore.clear()
                isStudying = false
                isPaused = false
                studyStartedAt = nil
            }
        } else if status.isStudying {
            // Not studying locally but the server says we are (started on another device).
            let start = status.startedAt ?? Date()
            let paused = status.isPaused ?? false
            let acc = Double(status.accumulatedSeconds ?? 0)
            LocalStudyStore.localStartedAt = start
            LocalStudyStore.isPaused = paused
            LocalStudyStore.accumulatedSeconds = acc
            if !paused {
                LocalStudyStore.segmentStartedAt = start
            }
            LocalStudyStore.startedOffline = false
            isStudying = true
            isPaused = paused
            studyStartedAt = start
        } else {
            isStudying = false
            isPaused = false
            studyStartedAt = nil
        }
    }

    /// Reconcile the study state against the server. The server flag is the shared
    /// "studying" signal across devices; the device's local timer is what we measure
    /// with (seeded from the server for sessions started on another device).
    private func refreshStudyState() async {
        guard !isRefreshingStudyState else { return }
        isRefreshingStudyState = true
        defer { isRefreshingStudyState = false }

        // Offline (or server unreachable): trust the local session; it keeps ticking.
        guard network.isOnline else {
            applyLocalSession()
            return
        }

        let status: MyStudyStatus
        do {
            status = try await APIClient.getMyStudyStatus()
        } catch {
            // Couldn't reach the server: fall back to the local session.
            applyLocalSession()
            return
        }

        await applyStudyStatus(status)
    }

    private func applyLocalSession() {
        if let local = LocalStudyStore.localStartedAt {
            isStudying = true
            isPaused = LocalStudyStore.isPaused
            studyStartedAt = local
        } else {
            isStudying = false
            isPaused = false
            studyStartedAt = nil
        }
    }

    private func loadFeed() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer {
            isLoadingFeed = false
            hasLoadedFeed = true
        }

        do {
            feedError = nil
            let response = try await APIClient.getHomeFeed()
            feedUsers = response.users
            FeedCache.save(response.users)
        } catch APIError.networkError {
            feedError = nil
        } catch {
            if !error.isCancellation {
                feedError = error.localizedDescription
            }
        }
    }

    /// Unified polling: fetch following users, own study status, and unread notification count in 1 request.
    private func pollHome(force: Bool = false) async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer {
            isLoadingFeed = false
            hasLoadedFeed = true
        }

        guard network.isOnline else {
            applyLocalSession()
            return
        }

        do {
            feedError = nil
            let poll = try await APIClient.poll(force: force)
            feedUsers = poll.users
            FeedCache.save(poll.users)
            await applyStudyStatus(poll.studySession)
            appState.unreadNotificationCount = poll.unreadCount
        } catch APIError.networkError {
            feedError = nil
            applyLocalSession()
        } catch {
            if !error.isCancellation {
                feedError = error.localizedDescription
            }
        }
    }

    private func startPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Config.feedPollingInterval))
            await pollHome()
        }
    }

    private func startStudying() async {
        let now = Date()
        LocalStudyStore.start(at: now)
        isStudying = true
        isPaused = false
        studyStartedAt = now

        do {
            try await APIClient.startStudy()
            LocalStudyStore.startedOffline = false
        } catch {
            LocalStudyStore.startedOffline = true
        }
    }

    private func pauseStudying() async {
        LocalStudyStore.pause()
        isPaused = true

        if network.isOnline {
            Task { try? await APIClient.pauseStudy() }
        }
    }

    private func resumeStudying() async {
        LocalStudyStore.resume()
        isPaused = false

        if network.isOnline {
            Task { try? await APIClient.resumeStudy() }
        }
    }

    private func stopStudying() {
        let totalElapsed = LocalStudyStore.totalElapsedSeconds()
        let elapsedMinutes = Int(totalElapsed / 60)
        LocalStudyStore.clear()
        isStudying = false
        isPaused = false
        studyStartedAt = nil

        composeInitialMinutes = max(1, elapsedMinutes)
        showComposePost = true

        if network.isOnline {
            Task { try? await APIClient.stopStudy() }
        }
    }

    // MARK: - Post Actions

    private func loadFollowingPosts() async {
        guard !isLoadingFollowingPosts else { return }
        isLoadingFollowingPosts = true
        postsError = nil
        defer {
            isLoadingFollowingPosts = false
            hasLoadedFollowingPosts = true
        }
        do {
            let response = try await APIClient.getTimeline(cursor: nil, limit: pageSize)
            followingPosts = response.posts
            followingNextCursor = response.nextCursor
            PostsCache.save(response.posts, scopeKey: "following")
        } catch {
            if !error.isCancellation {
                postsError = error.localizedDescription
            }
        }
    }

    private func loadMyPosts() async {
        guard !isLoadingMyPosts else { return }
        isLoadingMyPosts = true
        postsError = nil
        defer {
            isLoadingMyPosts = false
            hasLoadedMyPosts = true
        }
        do {
            let response = try await APIClient.getUserPosts(userId: "me", cursor: nil, limit: pageSize)
            myPosts = response.posts
            myNextCursor = response.nextCursor
            PostsCache.save(response.posts, scopeKey: "mine")
        } catch {
            if !error.isCancellation {
                postsError = error.localizedDescription
            }
        }
    }

    private func loadMoreCurrentPosts() {
        switch postScope {
        case .following:
            guard let cursor = followingNextCursor, !isLoadingMoreFollowingPosts, !isLoadingFollowingPosts else { return }
            Task {
                isLoadingMoreFollowingPosts = true
                defer { isLoadingMoreFollowingPosts = false }
                do {
                    let response = try await APIClient.getTimeline(cursor: cursor, limit: pageSize)
                    followingPosts.append(contentsOf: response.posts)
                    followingNextCursor = response.nextCursor
                } catch { }
            }
        case .mine:
            guard let cursor = myNextCursor, !isLoadingMoreMyPosts, !isLoadingMyPosts else { return }
            Task {
                isLoadingMoreMyPosts = true
                defer { isLoadingMoreMyPosts = false }
                do {
                    let response = try await APIClient.getUserPosts(userId: "me", cursor: cursor, limit: pageSize)
                    myPosts.append(contentsOf: response.posts)
                    myNextCursor = response.nextCursor
                } catch { }
            }
        }
    }

    private func prependPost(_ studyPost: StudyPost) {
        guard let me = appState.currentUser else { return }
        let post = Post(
            id: studyPost.id,
            userId: me.id,
            minutes: studyPost.minutes,
            comment: studyPost.comment,
            createdAt: studyPost.createdAt,
            user: me
        )
        myPosts.insert(post, at: 0)
        PostsCache.save(myPosts, scopeKey: "mine")

        followingPosts.insert(post, at: 0)
        PostsCache.save(followingPosts, scopeKey: "following")
    }

    private func deletePost(_ post: Post) async {
        do {
            try await APIClient.deletePost(id: post.id)
            myPosts.removeAll { $0.id == post.id }
            PostsCache.save(myPosts, scopeKey: "mine")

            followingPosts.removeAll { $0.id == post.id }
            PostsCache.save(followingPosts, scopeKey: "following")
        } catch {
            if !error.isCancellation {
                postsError = error.localizedDescription
            }
        }
    }

    private func reportPost(_ post: Post) async {
        do {
            try await APIClient.reportPost(id: post.id)
            showReportSuccessAlert = true
        } catch {
            if !error.isCancellation {
                postsError = error.localizedDescription
            }
        }
    }

    private func updatePostLike(id: String, isLiked: Bool, likeCount: Int) {
        if let idx = followingPosts.firstIndex(where: { $0.id == id }) {
            followingPosts[idx].isLiked = isLiked
            followingPosts[idx].likeCount = likeCount
            PostsCache.save(followingPosts, scopeKey: "following")
        }
        if let idx = myPosts.firstIndex(where: { $0.id == id }) {
            myPosts[idx].isLiked = isLiked
            myPosts[idx].likeCount = likeCount
            PostsCache.save(myPosts, scopeKey: "mine")
        }
    }

    private func updatePostContent(id: String, minutes: Int, comment: String?) {
        if let idx = followingPosts.firstIndex(where: { $0.id == id }) {
            let old = followingPosts[idx]
            followingPosts[idx] = Post(
                id: old.id,
                userId: old.userId,
                minutes: minutes,
                comment: comment,
                createdAt: old.createdAt,
                user: old.user,
                likeCount: old.likeCount,
                isLiked: old.isLiked
            )
            PostsCache.save(followingPosts, scopeKey: "following")
        }
        if let idx = myPosts.firstIndex(where: { $0.id == id }) {
            let old = myPosts[idx]
            myPosts[idx] = Post(
                id: old.id,
                userId: old.userId,
                minutes: minutes,
                comment: comment,
                createdAt: old.createdAt,
                user: old.user,
                likeCount: old.likeCount,
                isLiked: old.isLiked
            )
            PostsCache.save(myPosts, scopeKey: "mine")
        }
    }

    private func handlePostMilestone() {
        PostCountStore.handlePostCompleted(
            onInviteFriends: {
                showInviteFriendsAlert = true
            }
        )
    }

    private func shareMyProfile() {
        guard let userId = appState.currentUser?.id ?? ProfileCache.load()?.id,
              let url = URL(string: "https://junjun.oyajun.com/u/\(String(userId.prefix(10)))") else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Helpers

    private func formatElapsed(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func elapsedString(from start: Date, to current: Date) -> String {
        let seconds = Int(current.timeIntervalSince(start))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - Studying Button Glow

private struct StudyingButtonGlow: View {
    var backgroundColor: String = "#FFD54F"
    var isPro: Bool = false
    @State private var rotation: Double = 0

    private var glowColors: [Color] {
        if isPro {
            return IconPresets.rainbowColors
        } else {
            return Color.neighboringColors(from: backgroundColor)
        }
    }

    var body: some View {
        let gradient = AngularGradient(
            colors: glowColors,
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )

        // Clean, single ambient glow behind the button matching screen edge glow intensity
        Capsule(style: .continuous)
            .fill(gradient)
            .padding(-8)
            .drawingGroup() // Offload rendering pass to Metal (GPU)
            .blur(radius: 16)
            .opacity(0.60)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
