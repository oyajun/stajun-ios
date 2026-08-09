import SwiftUI

struct BlockedUsersView: View {
    @State private var users: [UserWithFollowStatus] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasMore = false
    @State private var offset = 0
    private let limit = 20

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, users.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if users.isEmpty {
                ContentUnavailableView("No Blocked Users", systemImage: "person.crop.circle.badge.xmark")
            } else {
                List {
                    ForEach(users) { user in
                        HStack(spacing: 12) {
                            UserIconView(
                                emoji: user.iconEmoji,
                                backgroundColor: user.iconBackgroundColor,
                                size: 40
                            )
                            Text(user.name)
                                .font(.body.weight(.medium))
                            Spacer()
                            Button("Unblock") {
                                Task { await unblockUser(user) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        .padding(.vertical, 4)
                        .onAppear {
                            if user.id == users.last?.id {
                                loadMore()
                            }
                        }
                    }
                    if hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadInitial()
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if users.isEmpty {
                await loadInitial()
            }
        }
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIClient.getBlockedUsers(limit: limit, offset: 0)
            users = response.users
            hasMore = response.pagination.hasMore
            offset = response.pagination.offset + response.users.count
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadMore() {
        guard hasMore, !isLoading else { return }
        Task {
            isLoading = true
            do {
                let response = try await APIClient.getBlockedUsers(limit: limit, offset: offset)
                users.append(contentsOf: response.users)
                hasMore = response.pagination.hasMore
                offset = response.pagination.offset + response.users.count
            } catch {
                // Ignore pagination errors silently
            }
            isLoading = false
        }
    }

    private func unblockUser(_ user: UserWithFollowStatus) async {
        do {
            try await APIClient.unblockUser(userId: user.id)
            users.removeAll { $0.id == user.id }
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}
