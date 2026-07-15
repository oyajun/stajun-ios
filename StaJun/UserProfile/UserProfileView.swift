import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AppState.self) private var appState

    @State private var user: UserWithStudyStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFollowLoading = false

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
                ContentUnavailableView("ユーザーが見つかりません", systemImage: "person.slash")
            }
        }
        .navigationTitle(user?.username ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func userContent(_ user: UserWithStudyStatus) -> some View {
        List {
            // アイコン・ステータス
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        UserIconView(
                            emoji: user.iconEmoji,
                            backgroundColor: user.iconBackgroundColor,
                            size: 80,
                            isStudying: user.isStudying
                        )
                        Text(user.username)
                            .font(.title2.bold())

                        if user.isStudying {
                            Label("勉強中", systemImage: "book.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        } else {
                            Text("休憩中")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // フォローボタン（自分以外）
            if !isOwnProfile {
                Section {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack {
                            Spacer()
                            if isFollowLoading {
                                ProgressView()
                            } else {
                                Text(user.isFollowing ?? false ? "フォロー中" : "フォローする")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .tint(user.isFollowing ?? false ? .secondary : .accentColor)
                    .disabled(isFollowLoading)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            user = try await APIClient.getUser(id: userId)
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .environment(AppState())
    }
}
