import SwiftUI
import Foundation
import UIKit

enum PostScope: String, CaseIterable, Hashable {
    case following
    case mine

    var title: String {
        switch self {
        case .following: return "Following"
        case .mine: return "Mine"
        }
    }
    var cacheKey: String { rawValue }
}

struct TimelineState {
    var posts: [Post] = []
    var nextCursor: String?
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var hasLoaded: Bool = false
}

@Observable
@MainActor
final class HomeViewModel {
    // MARK: - Study Status
    var isStudying: Bool = LocalStudyStore.localStartedAt != nil
    var isPaused: Bool = LocalStudyStore.isPaused
    var studyStartedAt: Date?
    var studyActionLoading: Bool = false
    var isStartingStudy: Bool = false
    var studyError: String?
    var currentActivity: String? = LocalStudyStore.currentActivity
    var showEditActivitySheet: Bool = false

    // MARK: - Feed
    var feedUsers: [UserWithStudyStatus] = []
    var feedError: String?
    var isRefreshingStudyState: Bool = false
    var isLoadingFeed: Bool = false
    var hasLoadedFeed: Bool = false

    // MARK: - Timeline Posts
    let pageSize = 20
    let firstAdIndex = 1
    let adInterval = 7
    var adRefreshID = UUID()

    var postScope: PostScope = .following
    var postTimelines: [PostScope: TimelineState] = [
        .following: TimelineState(),
        .mine: TimelineState()
    ]
    var postsError: String?

    // MARK: - Sheets & Alerts
    var showCompose: Bool = false
    var postToEdit: Post?
    var postToDelete: Post?
    var postToReport: Post?
    var showReportSuccessAlert: Bool = false
    var showInviteFriendsAlert: Bool = false

    var showComposePost: Bool = false
    var composeInitialMinutes: Int = 0
    var composeInitialComment: String?

    // MARK: - Timer
    var now: Date = Date()

    // MARK: - Computed Properties
    var currentTimeline: TimelineState { postTimelines[postScope] ?? TimelineState() }
    var currentPosts: [Post] { currentTimeline.posts }
    var hasLoadedCurrentPosts: Bool { currentTimeline.hasLoaded }
    var isLoadingMoreCurrentPosts: Bool { currentTimeline.isLoadingMore }

    // MARK: - Initial Caches
    func loadInitialCaches() {
        if feedUsers.isEmpty {
            let cached = FeedCache.load()
            if !cached.isEmpty {
                feedUsers = cached
                hasLoadedFeed = true
            }
        }
        for scope in PostScope.allCases {
            if postTimelines[scope]?.posts.isEmpty ?? true {
                let cached = PostsCache.load(scopeKey: scope.cacheKey)
                if !cached.isEmpty {
                    postTimelines[scope]?.posts = cached
                    postTimelines[scope]?.hasLoaded = true
                }
            }
        }
    }

    // MARK: - Study Actions & Sync
    func applyStudyStatus(_ status: MyStudyStatus) async {
        if LocalStudyStore.pendingStop {
            if status.isStudying {
                Task {
                    do {
                        try await APIClient.stopStudy()
                        LocalStudyStore.pendingStop = false
                    } catch { }
                }
            } else {
                LocalStudyStore.pendingStop = false
            }
            return
        }

        if let local = LocalStudyStore.localStartedAt {
            isStudying = true
            isPaused = LocalStudyStore.isPaused
            studyStartedAt = local
            currentActivity = LocalStudyStore.currentActivity

            if status.isStudying {
                LocalStudyStore.startedOffline = false
            } else if LocalStudyStore.startedOffline {
                do {
                    try await APIClient.startStudy(activity: LocalStudyStore.currentActivity)
                    LocalStudyStore.startedOffline = false
                } catch { }
            } else {
                let isRecentlyStarted = Date().timeIntervalSince(local) < 60
                if isStartingStudy || isRecentlyStarted {
                    if !isStartingStudy {
                        Task { try? await APIClient.startStudy(activity: LocalStudyStore.currentActivity) }
                    }
                } else {
                    LocalStudyStore.clear()
                    resetStudyUI()
                }
            }
        } else if status.isStudying {
            guard !isStartingStudy else { return }
            let start = status.startedAt ?? Date()
            let paused = status.isPaused ?? false
            LocalStudyStore.localStartedAt = start
            LocalStudyStore.isPaused = paused
            LocalStudyStore.accumulatedSeconds = Double(status.accumulatedSeconds ?? 0)
            LocalStudyStore.currentActivity = status.activity
            if !paused { LocalStudyStore.segmentStartedAt = start }
            LocalStudyStore.startedOffline = false

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isStudying = true
                isPaused = paused
                studyStartedAt = start
                currentActivity = status.activity
            }
        } else {
            guard !isStartingStudy else { return }
            resetStudyUI()
        }
    }

    private func resetStudyUI() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isStudying = false
            isPaused = false
            studyStartedAt = nil
            currentActivity = nil
        }
    }

    func applyLocalSession() {
        isStudying = LocalStudyStore.localStartedAt != nil
        isPaused = LocalStudyStore.isPaused
        studyStartedAt = LocalStudyStore.localStartedAt
        currentActivity = LocalStudyStore.currentActivity
    }

    func startStudying() async {
        guard !studyActionLoading else { return }
        studyActionLoading = true
        isStartingStudy = true
        defer {
            studyActionLoading = false
            isStartingStudy = false
        }

        let now = Date()
        LocalStudyStore.start(at: now, offline: true)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isStudying = true
            isPaused = false
            studyStartedAt = now
            currentActivity = nil
        }

        do {
            try await APIClient.startStudy()
            LocalStudyStore.startedOffline = false
        } catch {
            LocalStudyStore.startedOffline = true
        }
    }

    func pauseStudying() async {
        LocalStudyStore.pause()
        isPaused = true
        if NetworkMonitor.shared.isOnline {
            Task { try? await APIClient.pauseStudy() }
        }
    }

    func resumeStudying() async {
        LocalStudyStore.resume()
        isPaused = false
        if NetworkMonitor.shared.isOnline {
            Task { try? await APIClient.resumeStudy() }
        }
    }

    func stopStudying() {
        let elapsedMinutes = Int(LocalStudyStore.totalElapsedSeconds() / 60)
        let lastActivity = currentActivity

        LocalStudyStore.clear()
        resetStudyUI()

        composeInitialMinutes = max(1, elapsedMinutes)
        composeInitialComment = lastActivity
        showComposePost = true

        if NetworkMonitor.shared.isOnline {
            Task { try? await APIClient.stopStudy() }
        }
    }

    func updateActivity(_ newActivity: String?) {
        LocalStudyStore.currentActivity = newActivity
        withAnimation(.easeInOut(duration: 0.2)) {
            currentActivity = newActivity
        }
        if NetworkMonitor.shared.isOnline {
            Task { try? await APIClient.updateStudyActivity(newActivity) }
        }
    }

    // MARK: - Polling & Feed
    private func saveFeedUsers(_ users: [UserWithStudyStatus]) {
        feedUsers = users
        FeedCache.save(users)
        for u in users { UserProfileCache.save(u, userId: u.id) }
    }

    func loadFeed() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer {
            isLoadingFeed = false
            hasLoadedFeed = true
        }

        do {
            feedError = nil
            let response = try await APIClient.getHomeFeed()
            saveFeedUsers(response.users)
        } catch APIError.networkError {
            feedError = nil
        } catch {
            if !error.isCancellation { feedError = error.localizedDescription }
        }
    }

    func pollHome(force: Bool = false, appState: AppState) async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer {
            isLoadingFeed = false
            hasLoadedFeed = true
        }

        guard NetworkMonitor.shared.isOnline else {
            applyLocalSession()
            return
        }

        do {
            feedError = nil
            let poll = try await APIClient.poll(force: force)
            saveFeedUsers(poll.users)
            await applyStudyStatus(poll.studySession)
            appState.unreadNotificationCount = poll.unreadCount
        } catch APIError.networkError {
            feedError = nil
            applyLocalSession()
        } catch {
            if !error.isCancellation { feedError = error.localizedDescription }
        }
    }

    func startPolling(appState: AppState) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Config.feedPollingInterval))
            await pollHome(appState: appState)
        }
    }

    func refreshTimelineAndFeed(appState: AppState) async {
        AdBannerCache.shared.clearCache()
        TimelineAdSlotManager.shared.reset()
        AffiliateCache.shared.clearItemCache()
        adRefreshID = UUID()

        await pollHome(force: true, appState: appState)
        await loadAllPosts()
    }

    // MARK: - Post Actions
    func loadPosts(scope: PostScope) async {
        guard !(postTimelines[scope]?.isLoading ?? false) else { return }
        postTimelines[scope]?.isLoading = true
        postsError = nil
        defer {
            postTimelines[scope]?.isLoading = false
            postTimelines[scope]?.hasLoaded = true
        }

        do {
            let response = try await (scope == .following
                ? APIClient.getTimeline(cursor: nil, limit: pageSize)
                : APIClient.getUserPosts(userId: "me", cursor: nil, limit: pageSize))
            postTimelines[scope]?.posts = response.posts
            postTimelines[scope]?.nextCursor = response.nextCursor
            PostsCache.save(response.posts, scopeKey: scope.cacheKey)
        } catch {
            if !error.isCancellation { postsError = error.localizedDescription }
        }
    }

    func loadAllPosts() async {
        await loadPosts(scope: .following)
        await loadPosts(scope: .mine)
    }

    func loadMoreCurrentPosts() {
        let scope = postScope
        guard let timeline = postTimelines[scope],
              let cursor = timeline.nextCursor,
              !timeline.isLoadingMore,
              !timeline.isLoading else { return }

        postTimelines[scope]?.isLoadingMore = true
        Task {
            defer { postTimelines[scope]?.isLoadingMore = false }
            do {
                let response = try await (scope == .following
                    ? APIClient.getTimeline(cursor: cursor, limit: pageSize)
                    : APIClient.getUserPosts(userId: "me", cursor: cursor, limit: pageSize))
                let existingIds = Set(postTimelines[scope]?.posts.map(\.id) ?? [])
                let uniqueNewPosts = response.posts.filter { !existingIds.contains($0.id) }
                postTimelines[scope]?.posts.append(contentsOf: uniqueNewPosts)
                postTimelines[scope]?.nextCursor = response.nextCursor
            } catch { }
        }
    }

    private func mutateAllTimelines(_ transform: (inout [Post]) -> Void) {
        for scope in PostScope.allCases {
            guard var posts = postTimelines[scope]?.posts else { continue }
            transform(&posts)
            postTimelines[scope]?.posts = posts
            PostsCache.save(posts, scopeKey: scope.cacheKey)
        }
    }

    func prependPost(_ studyPost: StudyPost, currentUser: UserProfile?) {
        guard let me = currentUser else { return }
        let post = Post(
            id: studyPost.id,
            userId: me.id,
            minutes: studyPost.minutes,
            comment: studyPost.comment,
            createdAt: studyPost.createdAt,
            user: me
        )
        mutateAllTimelines { $0.insert(post, at: 0) }
    }

    func deletePost(_ post: Post) async {
        do {
            try await APIClient.deletePost(id: post.id)
            mutateAllTimelines { $0.removeAll { $0.id == post.id } }
        } catch {
            if !error.isCancellation { postsError = error.localizedDescription }
        }
    }

    func reportPost(_ post: Post) async {
        do {
            try await APIClient.reportPost(id: post.id)
            showReportSuccessAlert = true
        } catch {
            if !error.isCancellation { postsError = error.localizedDescription }
        }
    }

    func updatePostLike(id: String, isLiked: Bool, likeCount: Int) {
        mutateAllTimelines { posts in
            if let idx = posts.firstIndex(where: { $0.id == id }) {
                posts[idx].isLiked = isLiked
                posts[idx].likeCount = likeCount
            }
        }
    }

    func updatePostContent(id: String, minutes: Int, comment: String?) {
        mutateAllTimelines { posts in
            if let idx = posts.firstIndex(where: { $0.id == id }) {
                let post = posts[idx]
                posts[idx] = Post(
                    id: post.id,
                    userId: post.userId,
                    minutes: minutes,
                    comment: comment,
                    createdAt: post.createdAt,
                    user: post.user,
                    likeCount: post.likeCount,
                    isLiked: post.isLiked
                )
            }
        }
    }

    func handlePostMilestone() {
        PostCountStore.handlePostCompleted { [weak self] in
            self?.showInviteFriendsAlert = true
        }
    }

    func shareMyProfile(currentUser: UserProfile?) {
        guard let userId = currentUser?.id ?? ProfileCache.load()?.id,
              let url = URL(string: "https://junjun.oyajun.com/u/\(String(userId.prefix(10)))") else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }
}
