import SwiftUI
import Combine
import UIKit

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var network = NetworkMonitor.shared

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !network.isOnline {
                    offlineBanner
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 0, trailing: 32))
                }

                // Study start/stop card + My active activity bubble
                VStack(alignment: .leading, spacing: 4) {
                    StudyCardView(
                        currentUser: appState.currentUser,
                        isPro: appState.isPro,
                        viewModel: viewModel,
                        onTapUser: {
                            if let userId = appState.currentUser?.id {
                                path.append(userId)
                            }
                        }
                    )
                    .animation(nil, value: viewModel.isStudying)

                    if viewModel.isStudying {
                        myActivitySection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 20, leading: 32, bottom: 0, trailing: 32))

                // Following users
                FollowingUsersFeedView(
                    feedUsers: viewModel.feedUsers,
                    hasLoadedFeed: viewModel.hasLoadedFeed,
                    isStudying: viewModel.isStudying,
                    now: viewModel.now,
                    onSelectUser: { path.append($0) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

                // Scope picker + compose button
                HStack {
                    Picker("Scope", selection: $viewModel.postScope) {
                        ForEach(PostScope.allCases, id: \.self) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.showCompose = true
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

                // Posts list
                if !viewModel.hasLoadedCurrentPosts && viewModel.currentPosts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 48)
                } else if viewModel.currentPosts.isEmpty {
                    emptyPostsSection
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                } else {
                    ForEach(Array(viewModel.currentPosts.enumerated()), id: \.element.id) { index, post in
                        timelinePostRow(post)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())

                        if Config.showAds && !appState.isPro && index >= viewModel.firstAdIndex && (index - viewModel.firstAdIndex) % viewModel.adInterval == 0 {
                            HomeTimelineAdRow(
                                index: index,
                                firstAdIndex: viewModel.firstAdIndex,
                                adInterval: viewModel.adInterval,
                                adRefreshID: viewModel.adRefreshID
                            )
                        }
                    }
                }

                if viewModel.isLoadingMoreCurrentPosts {
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
                await viewModel.refreshTimelineAndFeed(appState: appState)
            }
            .task {
                await viewModel.initializeIfNeeded(appState: appState)
                await viewModel.startPolling(appState: appState)
            }
            .onChange(of: viewModel.isStudying) { _, newValue in
                appState.isStudying = newValue
            }
            .onChange(of: viewModel.isPaused) { _, newValue in
                appState.isPaused = newValue
            }
            .onChange(of: network.isOnline) { _, online in
                if online { Task { await viewModel.pollHome(appState: appState) } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await viewModel.pollHome(appState: appState)
                        await NotificationHandler.setDeviceToken()
                    }
                }
            }
            .onReceive(
                Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            ) { _ in
                viewModel.now = Date()
            }
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .navigationDestination(for: Post.self) { post in
                PostDetailView(
                    post: post,
                    onDelete: {
                        Task { await viewModel.deletePost(post) }
                    },
                    onToggleLike: { isLiked, count in
                        viewModel.updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
                    },
                    onUpdate: { updated in
                        viewModel.updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
                    }
                )
            }
            .sheet(item: $viewModel.postToEdit) { post in
                EditPostView(post: post) { updated in
                    viewModel.updatePostContent(id: updated.id, minutes: updated.minutes, comment: updated.comment)
                }
            }
            .sheet(isPresented: $viewModel.showComposePost) {
                ComposePostView(initialMinutes: viewModel.composeInitialMinutes, initialComment: viewModel.composeInitialComment) { newPost in
                    handleNewPost(newPost)
                }
            }
            .sheet(isPresented: $viewModel.showEditActivitySheet) {
                ActivityEditSheet(initialActivity: viewModel.currentActivity) { newActivity in
                    viewModel.updateActivity(newActivity)
                }
            }
            .sheet(isPresented: $viewModel.showCompose) {
                ComposePostView { newPost in
                    handleNewPost(newPost)
                }
            }
            .alert("Delete Post", isPresented: Binding(
                get: { viewModel.postToDelete != nil },
                set: { if !$0 { viewModel.postToDelete = nil } }
            ), presenting: viewModel.postToDelete) { post in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deletePost(post) }
                }
            } message: { _ in
                Text("Are you sure you want to delete this post?")
            }
            .alert("Report Post", isPresented: Binding(
                get: { viewModel.postToReport != nil },
                set: { if !$0 { viewModel.postToReport = nil } }
            ), presenting: viewModel.postToReport) { post in
                Button("Cancel", role: .cancel) { }
                Button("Report", role: .destructive) {
                    Task { await viewModel.reportPost(post) }
                }
            } message: { _ in
                Text("Are you sure you want to report this post?")
            }
            .alert("Report Submitted", isPresented: $viewModel.showReportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you for reporting this post.")
            }
            .alert("Invite Your Friends!", isPresented: $viewModel.showInviteFriendsAlert) {
                Button("Share Your Profile") {
                    viewModel.shareMyProfile(currentUser: appState.currentUser)
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Have your friends install the app and follow each other.\nYou'll be able to see when and what they are studying!")
            }
            .overlay(alignment: .bottom) {
                if let postsError = viewModel.postsError, !viewModel.currentPosts.isEmpty {
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

    private func handleNewPost(_ newPost: StudyPost) {
        viewModel.prependPost(newPost, currentUser: appState.currentUser)
        Task {
            await viewModel.loadAllPosts()
            await viewModel.loadFeed()
        }
        viewModel.handlePostMilestone()
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

    // MARK: - My Activity Section

    private var myAvatarCenter: CGFloat {
        let name = appState.currentUser?.name ?? ""
        let font = UIFont.systemFont(ofSize: 12)
        let nameWidth = (name as NSString).size(withAttributes: [.font: font]).width
        let columnWidth = max(52, nameWidth)
        return columnWidth / 2
    }

    @ViewBuilder
    private var myActivitySection: some View {
        HStack {
            let myTintColor = Color(hex: appState.currentUser?.iconBackgroundColor ?? "") ?? .orange
            MyActivityBubble(
                activity: viewModel.currentActivity,
                tailX: myAvatarCenter,
                tintColor: myTintColor,
                onEdit: {
                    viewModel.showEditActivitySheet = true
                }
            )
            Spacer()
        }
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
            Text(viewModel.postScope == .following
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
                viewModel.updatePostLike(id: post.id, isLiked: isLiked, likeCount: count)
            },
            onTapDetail: {
                path.append(post)
            }
        )
        .onAppear {
            if post.id == viewModel.currentPosts.last?.id {
                viewModel.loadMoreCurrentPosts()
            }
        }

        if post.userId == appState.currentUser?.id {
            base
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.postToDelete = post
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        viewModel.postToEdit = post
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        viewModel.postToEdit = post
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        viewModel.postToDelete = post
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            base
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.postToReport = post
                    } label: {
                        Label("Report", systemImage: "exclamationmark.bubble")
                    }
                }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
