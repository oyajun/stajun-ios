import SwiftUI

/// Home timeline: study-time posts from the current user and people they follow,
/// switchable between the following feed and the user's own posts.
struct PostTimelineView: View {
    private let pageSize = 20

    /// Which posts the timeline shows.
    private enum Scope: Hashable {
        case following  // Home feed: self + following (GET /posts)
        case mine       // Own posts only (GET /posts?userId=me)

        var title: String {
            switch self {
            case .following: return "Following"
            case .mine: return "Mine"
            }
        }
    }

    @Environment(AppState.self) private var appState

    @State private var scope: Scope = .following
    @State private var posts: [Post] = []
    @State private var nextCursor: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showCompose = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    Text(Scope.following.title).tag(Scope.following)
                    Text(Scope.mine.title).tag(Scope.mine)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable { await load() }
            .task {
                if posts.isEmpty { await load() }
            }
            .onChange(of: scope) { _, _ in
                Task { await load(reset: true) }
            }
            .sheet(isPresented: $showCompose) {
                ComposePostView { newPost in
                    prepend(newPost)
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage, !posts.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty {
                ContentUnavailableView(
                    "No Posts Yet",
                    systemImage: "square.and.pencil",
                    description: Text(emptyDescription)
                )
            } else {
                    List {
                        ForEach(posts) { post in
                            postRow(post)
                        }

                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }

    /// A timeline row. Own posts get a long-press menu to delete; others don't.
    @ViewBuilder
    private func postRow(_ post: Post) -> some View {
        let base = PostRow(post: post, onTapAuthor: { path.append(post.userId) })
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .onAppear {
                if post.id == posts.last?.id {
                    loadMore()
                }
            }
        if post.userId == appState.currentUser?.id {
            base
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await delete(post) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await delete(post) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            base
        }
    }

    private var emptyDescription: String {
        switch scope {
        case .following: return "Posts from you and people you follow will appear here."
        case .mine: return "Your posts will appear here."
        }
    }

    // MARK: - Data

    /// Fetch a page of posts for the current scope.
    private func fetchPosts(cursor: String?) async throws -> PostsResponse {
        switch scope {
        case .following:
            return try await APIClient.getTimeline(cursor: cursor, limit: pageSize)
        case .mine:
            return try await APIClient.getUserPosts(userId: "me", cursor: cursor, limit: pageSize)
        }
    }

    private func load(reset: Bool = false) async {
        if reset {
            posts = []
            nextCursor = nil
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await fetchPosts(cursor: nil)
            posts = response.posts
            nextCursor = response.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() {
        guard let cursor = nextCursor, !isLoadingMore, !isLoading else { return }
        Task {
            isLoadingMore = true
            defer { isLoadingMore = false }
            do {
                let response = try await fetchPosts(cursor: cursor)
                posts.append(contentsOf: response.posts)
                nextCursor = response.nextCursor
            } catch {
                // Ignore pagination errors; scrolling again retries.
            }
        }
    }

    /// Insert a freshly created post at the top (author info from current user).
    private func prepend(_ studyPost: StudyPost) {
        guard let me = appState.currentUser else {
            Task { await load() }
            return
        }
        let post = Post(
            id: studyPost.id,
            userId: me.id,
            minutes: studyPost.minutes,
            comment: studyPost.comment,
            createdAt: studyPost.createdAt,
            user: me
        )
        posts.insert(post, at: 0)
    }

    private func delete(_ post: Post) async {
        do {
            try await APIClient.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PostTimelineView()
        .environment(AppState())
}
