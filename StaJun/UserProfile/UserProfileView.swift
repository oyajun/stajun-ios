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
                ContentUnavailableView("User Not Found", systemImage: "person.slash")
            }
        }
        .navigationTitle(user?.username ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func userContent(_ user: UserWithStudyStatus) -> some View {
        List {
            // Icon and status
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
                            Label("Studying", systemImage: "book.fill")
                                .font(.body)
                                .foregroundStyle(.orange)
                        } else {
                            Text("On Break")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Follow button (for other users)
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
                                Text(user.isFollowing ?? false ? "Following" : "Follow")
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
                    Text(errorMessage).foregroundStyle(.red).font(.subheadline)
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
