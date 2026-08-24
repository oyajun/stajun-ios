import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    // Navigation
    @State private var path = NavigationPath()

    // Study status — initialise from local store so the border appears immediately on launch
    @State private var isStudying = LocalStudyStore.localStartedAt != nil
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
    @State private var postToDelete: Post?
    @State private var postToReport: Post?
    @State private var showReportSuccessAlert = false

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

                        if Config.showAds && index >= firstAdIndex && (index - firstAdIndex) % adInterval == 0 {
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
                await refreshStudyState()
                await loadFeed()
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
                await refreshStudyState()
                await loadFeed()
                await loadFollowingPosts()
                await loadMyPosts()
                await startPolling()
            }
            .onChange(of: isStudying) { _, newValue in
                appState.isStudying = newValue
            }
            .onChange(of: network.isOnline) { _, online in
                if online {
                    Task { await refreshStudyState() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await refreshStudyState()
                        await loadFeed()
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
            .sheet(isPresented: $showComposePost) {
                ComposePostView(initialMinutes: composeInitialMinutes) { newPost in
                    prependPost(newPost)
                    Task {
                        await loadFollowingPosts()
                        await loadMyPosts()
                        await loadFeed()
                    }
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
                        isStudying: isStudying
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
                    Text(isStudying ? elapsedString(from: studyStartedAt ?? now, to: now) : "--:--")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(isStudying ? .orange : .secondary)
                    Spacer()
                    Text(isStudying ? "Studying" : "Not Studying")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    Task { await toggleStudy() }
                } label: {
                    Group {
                        if studyActionLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isStudying ? "Stop Studying" : "Start Studying")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(isStudying ? .red : .accentColor)
                .disabled(studyActionLoading)
                .background {
                    if isStudying {
                        StudyingButtonGlow(
                            backgroundColor: appState.currentUser?.iconBackgroundColor ?? "#FFD54F"
                        )
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
                                    isStudying: user.isStudying
                                )
                                Text(user.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.top, 8)
                                if user.isStudying, let since = user.studyingSince {
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
        let base = PostRow(post: post, onTapAuthor: { path.append(post.userId) })
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
                }
                .contextMenu {
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
                if slotIndex % 2 == 0 {
                    AdBannerCard(cacheKey: "timeline-admob-\(index)")
                } else {
                    AffiliateBannerCard(cacheKey: "timeline-affiliate-\(index)")
                }
            } else {
                AdBannerCard(cacheKey: "timeline-admob-\(index)")
            }
            Divider()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Study Actions

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

        if let local = LocalStudyStore.localStartedAt {
            // Studying locally: the local timer stays the measured one either way.
            isStudying = true
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
                studyStartedAt = nil
            }
        } else if status.isStudying {
            // Not studying locally but the server says we are (started on another device).
            let start = status.startedAt ?? Date()
            LocalStudyStore.localStartedAt = start
            LocalStudyStore.startedOffline = false
            isStudying = true
            studyStartedAt = start
        } else {
            isStudying = false
            studyStartedAt = nil
        }
    }

    private func applyLocalSession() {
        if let local = LocalStudyStore.localStartedAt {
            isStudying = true
            studyStartedAt = local
        } else {
            isStudying = false
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

    private func startPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Config.feedPollingInterval))
            await refreshStudyState()
            await loadFeed()
            await appState.fetchUnreadNotificationCount()
        }
    }

    private func toggleStudy() async {
        studyError = nil
        if isStudying {
            stopStudying()
        } else {
            await startStudying()
        }
    }

    private func startStudying() async {
        let now = Date()
        LocalStudyStore.localStartedAt = now
        isStudying = true
        studyStartedAt = now

        do {
            try await APIClient.startStudy()
            LocalStudyStore.startedOffline = false
        } catch {
            LocalStudyStore.startedOffline = true
        }
    }

    private func stopStudying() {
        let start = LocalStudyStore.localStartedAt ?? studyStartedAt
        LocalStudyStore.clear()
        isStudying = false
        studyStartedAt = nil

        if let start {
            let elapsed = Int(Date().timeIntervalSince(start) / 60)
            composeInitialMinutes = max(1, elapsed)
            showComposePost = true
        }

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

    // MARK: - Helpers

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
    var cornerRadius: CGFloat = 16
    @State private var rotation: Double = 0

    // Rainbow colors (preserved)
    private static let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
    ]

    private var glowColors: [Color] {
        Color.neighboringColors(from: backgroundColor)
    }

    var body: some View {
        let gradient = AngularGradient(
            colors: glowColors,
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )

        /*
        // --- Original Rainbow Gradient (Preserved) ---
        let rainbowGradient = AngularGradient(
            colors: Self.rainbowColors,
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )
        */

        // Soft, frameless ambient glow behind the button
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(gradient)
            .padding(-6)
            .drawingGroup() // Offload rendering pass to Metal (GPU)
            .blur(radius: 16)
            .opacity(0.70)
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
