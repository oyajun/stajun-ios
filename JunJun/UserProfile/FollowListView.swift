import SwiftUI

enum FollowListType: String, Identifiable {
    case following
    case followers

    var id: String { rawValue }
}

struct FollowListView: View {
    let userId: String
    let userName: String?
    var initialTab: FollowListType = .following

    @Environment(AppState.self) private var appState
    @Environment(UserStore.self) private var userStore

    @State private var selectedTab: FollowListType
    @State private var followingUsers: [UserWithStudyStatus] = []
    @State private var followersUsers: [UserWithStudyStatus] = []
    @State private var isLoadingFollowing = true
    @State private var isLoadingFollowers = true
    @State private var errorMessage: String?
    @State private var showMuteAlert = false
    @State private var muteAlertTitle: LocalizedStringResource = ""

    init(userId: String, userName: String? = nil, initialTab: FollowListType = .following) {
        self.userId = userId
        self.userName = userName
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentUsers: [UserWithStudyStatus] {
        selectedTab == .following ? followingUsers : followersUsers
    }

    private var isLoadingCurrent: Bool {
        selectedTab == .following ? isLoadingFollowing : isLoadingFollowers
    }

    var body: some View {
        List {
            Picker("", selection: $selectedTab) {
                Text("Following Users").tag(FollowListType.following)
                Text("Followers").tag(FollowListType.followers)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isLoadingCurrent {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 48)
            } else if currentUsers.isEmpty {
                ContentUnavailableView("No users yet", systemImage: "person.2")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(currentUsers) { user in
                    let liveUser = userStore.user(for: user.id) ?? user
                    let isFollowing = liveUser.isFollowing ?? false
                    let isMuted = liveUser.isMuted ?? false

                    NavigationLink(destination: UserProfileView(userId: liveUser.id)) {
                        UserRow(
                            iconEmoji: liveUser.iconEmoji,
                            iconBackgroundColor: liveUser.iconBackgroundColor,
                            name: liveUser.name,
                            isStudying: liveUser.isStudying,
                            isPro: liveUser.id == appState.currentUser?.id ? appState.isPro : (liveUser.isPro ?? false),
                            isFollowing: isFollowing,
                            onFollowToggle: liveUser.id == appState.currentUser?.id
                                ? nil
                                : { toggleFollow(user: liveUser) }
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isFollowing && liveUser.id != appState.currentUser?.id {
                            Button {
                                toggleMute(user: liveUser)
                            } label: {
                                Label(
                                    isMuted ? "Unmute Notifications" : "Mute Notifications",
                                    systemImage: isMuted ? "bell" : "bell.slash"
                                )
                            }
                            .tint(isMuted ? .accentColor : .secondary)
                        }
                    }
                    .contextMenu {
                        if isFollowing && liveUser.id != appState.currentUser?.id {
                            Button {
                                toggleMute(user: liveUser)
                            } label: {
                                Label(
                                    isMuted ? "Unmute Notifications" : "Mute Notifications",
                                    systemImage: isMuted ? "bell" : "bell.slash"
                                )
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(userName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFollowing() }
        .task { await loadFollowers() }
        .alert(muteAlertTitle, isPresented: $showMuteAlert) {
            Button("OK", role: .cancel) { }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private func loadFollowing() async {
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }
        do {
            let fetched = try await APIClient.getFollowing(userId: userId).users
            userStore.upsert(fetched)
            followingUsers = fetched
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadFollowers() async {
        isLoadingFollowers = true
        defer { isLoadingFollowers = false }
        do {
            let fetched = try await APIClient.getFollowers(userId: userId).users
            userStore.upsert(fetched)
            followersUsers = fetched
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleFollow(user: UserWithStudyStatus) {
        let wasFollowing = userStore.user(for: user.id)?.isFollowing ?? (user.isFollowing ?? false)
        let newValue = !wasFollowing

        userStore.setFollowing(userId: user.id, isFollowing: newValue)
        if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
            followingUsers[i].isFollowing = newValue
            if !newValue {
                followingUsers[i].muteStudyStartNotification = 0
                followingUsers[i].isMuted = false
            }
        }
        if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
            followersUsers[i].isFollowing = newValue
            if !newValue {
                followersUsers[i].muteStudyStartNotification = 0
                followersUsers[i].isMuted = false
            }
        }

        Task {
            do {
                if wasFollowing {
                    try await APIClient.unfollow(userId: user.id)
                } else {
                    _ = try await APIClient.follow(userId: user.id)
                    appState.requestPushPermissionIfAppropriate()
                }
            } catch {
                userStore.setFollowing(userId: user.id, isFollowing: wasFollowing)
                if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
                    followingUsers[i].isFollowing = wasFollowing
                }
                if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
                    followersUsers[i].isFollowing = wasFollowing
                }
            }
        }
    }

    private func toggleMute(user: UserWithStudyStatus) {
        let currentLive = userStore.user(for: user.id) ?? user
        let previousMuted = (currentLive.isMuted == true) || (currentLive.muteStudyStartNotification == 1)
        let previousMode = currentLive.muteStudyStartNotification ?? (previousMuted ? 1 : 0)
        let targetMuted = !previousMuted
        let targetMode = targetMuted ? 1 : 0

        // 楽観的UI更新
        userStore.setMuted(userId: user.id, isMuted: targetMuted, muteNotification: targetMode)
        if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
            followingUsers[i].muteStudyStartNotification = targetMode
            followingUsers[i].isMuted = targetMuted
        }
        if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
            followersUsers[i].muteStudyStartNotification = targetMode
            followersUsers[i].isMuted = targetMuted
        }

        Task {
            do {
                let res = try await APIClient.updateFollowMute(userId: user.id, isMuted: targetMuted)
                let isMutedResult = res.isMuted ?? ((res.muteStudyStartNotification ?? targetMode) == 1)
                let modeResult = res.muteStudyStartNotification ?? (isMutedResult ? 1 : 0)
                userStore.setMuted(userId: user.id, isMuted: modeResult == 1, muteNotification: modeResult)
                if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
                    followingUsers[i].muteStudyStartNotification = modeResult
                    followingUsers[i].isMuted = isMutedResult
                }
                if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
                    followersUsers[i].muteStudyStartNotification = modeResult
                    followersUsers[i].isMuted = isMutedResult
                }
            } catch {
                userStore.setMuted(userId: user.id, isMuted: previousMuted, muteNotification: previousMode)
                if let i = followingUsers.firstIndex(where: { $0.id == user.id }) {
                    followingUsers[i].muteStudyStartNotification = previousMode
                    followingUsers[i].isMuted = previousMuted
                }
                if let i = followersUsers.firstIndex(where: { $0.id == user.id }) {
                    followersUsers[i].muteStudyStartNotification = previousMode
                    followersUsers[i].isMuted = previousMuted
                }
                muteAlertTitle = targetMuted ? "Could Not Mute" : "Could Not Unmute"
                showMuteAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        FollowListView(userId: "preview-user-id")
            .environment(AppState())
            .environment(UserStore())
    }
}
