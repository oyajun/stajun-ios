import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    private let pageSize = 20

    @State private var path = NavigationPath()
    @State private var notifications: [AppNotification] = []
    @State private var nextCursor: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !hasLoaded && notifications.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 48)
                } else if notifications.isEmpty {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash",
                        description: Text("You're all caught up!")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 48)
                } else {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                        notificationRow(notification)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .onAppear {
                                if index == notifications.count - 1 {
                                    loadMoreNotifications()
                                }
                            }
                    }
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 16)
                }
            }
            .listStyle(.plain)
            .navigationTitle(Text("Notifications"))
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if notifications.contains(where: { !$0.isRead }) {
                        Button {
                            markAllAsRead()
                        } label: {
                            Text("Mark All as Read")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .refreshable {
                await loadNotifications()
            }
            .task {
                if notifications.isEmpty {
                    let cached = NotificationsCache.load()
                    if !cached.isEmpty {
                        notifications = cached
                        hasLoaded = true
                    }
                }
                await loadNotifications()
            }
            .onChange(of: appState.deepLinkedUserId) { _, newId in
                guard let newId else { return }
                if let index = notifications.firstIndex(where: { $0.actor?.id == newId && !$0.isRead }) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        notifications[index].isRead = true
                    }
                    NotificationsCache.save(notifications)
                }
            }
        }
    }

    // MARK: - Actions

    private func markAllAsRead() {
        withAnimation(.easeInOut(duration: 0.2)) {
            for index in notifications.indices {
                notifications[index].isRead = true
            }
        }
        NotificationsCache.save(notifications)
        appState.unreadNotificationCount = 0
        Task {
            try? await APIClient.markAllNotificationsAsRead()
        }
    }

    private func markAsReadOptimistically(_ notification: AppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }),
              !notifications[index].isRead else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            notifications[index].isRead = true
        }
        NotificationsCache.save(notifications)
        if appState.unreadNotificationCount > 0 {
            appState.unreadNotificationCount -= 1
        }
        Task {
            try? await APIClient.markNotificationAsRead(id: notification.id)
        }
    }

    // MARK: - Row View

    @ViewBuilder
    private func notificationRow(_ notification: AppNotification) -> some View {
        Button {
            markAsReadOptimistically(notification)
            if let actor = notification.actor {
                path.append(actor.id)
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                // Fixed-width unread dot container to prevent layout shifting between unread and read
                Circle()
                    .fill(notification.isRead ? Color.clear : Color.accentColor)
                    .frame(width: 8, height: 8)
                    .frame(width: 12)

                if let actor = notification.actor {
                    UserIconView(
                        emoji: actor.iconEmoji,
                        backgroundColor: actor.iconBackgroundColor,
                        size: 44
                    )
                    .padding(.vertical, -8.8) // Match icon glow inset
                } else {
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let actor = notification.actor {
                            Text("\(Text(actor.name).font(.subheadline.bold()).foregroundStyle(.primary)) \(Text(LocalizedStringKey("started following you")).font(.subheadline).foregroundStyle(.secondary))")
                        } else {
                            Text(notification.extra ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                    Text(timeAgoText(for: notification.createdAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - API Calls

    private func loadNotifications() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let res = try await APIClient.getNotifications(limit: pageSize)
            notifications = res.notifications
            nextCursor = res.nextCursor
            appState.unreadNotificationCount = res.unreadCount
            NotificationsCache.save(res.notifications)
            hasLoaded = true
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadMoreNotifications() {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true

        Task {
            do {
                let res = try await APIClient.getNotifications(cursor: cursor, limit: pageSize)
                notifications.append(contentsOf: res.notifications)
                nextCursor = res.nextCursor
                NotificationsCache.save(notifications)
            } catch {
                #if DEBUG
                print("[Notifications] Failed to load more: \(error)")
                #endif
            }
            isLoadingMore = false
        }
    }

    // MARK: - Helpers

    private func timeAgoText(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let locale = Locale.autoupdatingCurrent

        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(
                .dateTime.locale(locale).hour().minute()
            )
        }

        let createdYear = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)
        if createdYear == currentYear {
            return date.formatted(
                .dateTime.locale(locale).month().day().hour().minute()
            )
        }

        return date.formatted(
            .dateTime.locale(locale).year().month().day().hour().minute()
        )
    }
}

#Preview {
    NotificationsView()
        .environment(AppState())
}
