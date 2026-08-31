import SwiftUI

struct PostDetailView: View {
    let post: Post
    var onDelete: (() -> Void)? = nil
    var onToggleLike: ((_ isLiked: Bool, _ likeCount: Int) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var currentPost: Post
    @State private var likers: [UserWithStudyStatus] = []
    @State private var isLoadingLikers = true
    @State private var isLoadingMoreLikers = false
    @State private var hasLoadedLikers = false
    @State private var likersOffset = 0
    @State private var hasMoreLikers = false
    private let pageSize = 20

    @State private var showDeleteAlert = false
    @State private var showReportAlert = false
    @State private var showReportSuccessAlert = false
    @State private var isDeleting = false
    @State private var isReporting = false
    @State private var errorMessage: String?
    @State private var navigateToAuthor = false

    init(
        post: Post,
        onDelete: (() -> Void)? = nil,
        onToggleLike: ((_ isLiked: Bool, _ likeCount: Int) -> Void)? = nil
    ) {
        self.post = post
        self.onDelete = onDelete
        self.onToggleLike = onToggleLike
        _currentPost = State(initialValue: post)
    }

    private var isOwnPost: Bool {
        currentPost.userId == appState.currentUser?.id
    }

    var body: some View {
        List {
            // Top: The post card (same as timeline)
            PostRow(
                post: currentPost,
                onTapAuthor: {
                    navigateToAuthor = true
                },
                onToggleLike: { isLiked, count in
                    handleLikeToggled(isLiked: isLiked, count: count)
                },
                onTapDetail: nil,
                showDivider: true
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())

            // Likes Section Header
            Section {
                if isLoadingLikers && likers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 32)
                } else if likers.isEmpty {
                    ContentUnavailableView(
                        "No likes yet",
                        systemImage: "heart.slash",
                        description: Text("Be the first to like this post!")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 32)
                } else {
                    ForEach(likers) { user in
                        NavigationLink(destination: UserProfileView(userId: user.id)) {
                            UserRow(
                                iconEmoji: user.iconEmoji,
                                iconBackgroundColor: user.iconBackgroundColor,
                                name: user.name,
                                isStudying: false,
                                isPro: user.id == appState.currentUser?.id ? appState.isPro : (user.isPro ?? false),
                                isFollowing: user.isFollowing ?? false,
                                onFollowToggle: user.id == appState.currentUser?.id ? nil : {
                                    toggleFollow(user: user)
                                }
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 32, bottom: 6, trailing: 32))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onAppear {
                            if user.id == likers.last?.id && hasMoreLikers && !isLoadingMoreLikers {
                                loadMoreLikers()
                            }
                        }
                    }

                    if isLoadingMoreLikers {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 16)
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Likes")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if currentPost.likeCount > 0 {
                        Text("\(currentPost.likeCount)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 16, leading: 32, bottom: 8, trailing: 32))
            }
        }
        .listStyle(.plain)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isOwnPost {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                } else {
                    Button {
                        showReportAlert = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                    .disabled(isReporting)
                }
            }
        }
        .task {
            await loadLikers()
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deletePost() }
            }
        } message: {
            Text("Are you sure you want to delete this post?")
        }
        .alert("Report Post", isPresented: $showReportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) {
                Task { await reportPost() }
            }
        } message: {
            Text("Are you sure you want to report this post?")
        }
        .alert("Report Submitted", isPresented: $showReportSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thank you for reporting this post.")
        }
        .navigationDestination(isPresented: $navigateToAuthor) {
            UserProfileView(userId: currentPost.userId)
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.red, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
    }

    // MARK: - Likes Handling

    private func handleLikeToggled(isLiked: Bool, count: Int) {
        currentPost.isLiked = isLiked
        currentPost.likeCount = count
        onToggleLike?(isLiked, count)

        guard let me = appState.currentUser else { return }
        if isLiked {
            if !likers.contains(where: { $0.id == me.id }) {
                let myEntry = UserWithStudyStatus(
                    id: me.id,
                    name: me.name,
                    iconEmoji: me.iconEmoji,
                    iconBackgroundColor: me.iconBackgroundColor,
                    isFollowing: nil,
                    muteStudyStartNotification: nil,
                    isMuted: nil,
                    isStudying: appState.isStudying,
                    studyingSince: nil,
                    isPro: appState.isPro
                )
                likers.insert(myEntry, at: 0)
            }
        } else {
            likers.removeAll { $0.id == me.id }
        }
    }

    private func loadLikers() async {
        isLoadingLikers = true
        defer {
            isLoadingLikers = false
            hasLoadedLikers = true
        }
        do {
            errorMessage = nil
            let res = try await APIClient.getPostLikes(postId: currentPost.id, limit: pageSize, offset: 0)
            likers = res.users
            likersOffset = res.users.count
            hasMoreLikers = res.pagination.hasMore
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadMoreLikers() {
        guard hasMoreLikers, !isLoadingMoreLikers else { return }
        Task {
            isLoadingMoreLikers = true
            defer { isLoadingMoreLikers = false }
            do {
                let res = try await APIClient.getPostLikes(
                    postId: currentPost.id,
                    limit: pageSize,
                    offset: likersOffset
                )
                likers.append(contentsOf: res.users)
                likersOffset += res.users.count
                hasMoreLikers = res.pagination.hasMore
            } catch {
                // Non-fatal
            }
        }
    }

    private func toggleFollow(user: UserWithStudyStatus) {
        Task {
            do {
                let wasFollowing = user.isFollowing ?? false
                if wasFollowing {
                    try await APIClient.unfollow(userId: user.id)
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    appState.requestPushPermissionIfAppropriate()
                }
                let newValue = !wasFollowing
                if let i = likers.firstIndex(where: { $0.id == user.id }) {
                    likers[i].isFollowing = newValue
                }
            } catch {
                // Ignore errors
            }
        }
    }

    // MARK: - Actions

    private func deletePost() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await APIClient.deletePost(id: currentPost.id)
            onDelete?()
            dismiss()
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reportPost() async {
        guard !isReporting else { return }
        isReporting = true
        defer { isReporting = false }
        do {
            try await APIClient.reportPost(id: currentPost.id)
            showReportSuccessAlert = true
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(
            post: Post(
                id: "1",
                userId: "u1",
                minutes: 90,
                comment: "詳細ページのテストです！",
                createdAt: Date(),
                user: UserProfile(
                    id: "u1",
                    name: "hanako",
                    iconEmoji: "🐣",
                    iconBackgroundColor: "#B3E5FC",
                    isAnonymous: false
                ),
                likeCount: 2,
                isLiked: true
            )
        )
        .environment(AppState())
    }
}
