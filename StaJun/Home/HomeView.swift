import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    // Study status
    @State private var isStudying = false
    @State private var studyStartedAt: Date?
    @State private var studyActionLoading = false
    @State private var studyError: String?

    // Feed
    @State private var feedUsers: [UserWithStudyStatus] = []
    @State private var feedError: String?
    @State private var isRefreshingStudyState = false
    @State private var isLoadingFeed = false

    // Timer (elapsed time display)
    @State private var now = Date()

    // Network reachability
    @State private var network = NetworkMonitor.shared

    // Post composer (shown after stopping a study session)
    @State private var showComposePost = false
    @State private var composeInitialMinutes = 0

    var body: some View {
        NavigationStack {
            List {
                // Offline banner
                if !network.isOnline {
                    offlineBanner
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Study start/stop card (Liquid Glass)
                studyCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                // Following users list
                if feedUsers.isEmpty {
                    emptyFeedSection
                } else {
                    Section("Following") {
                        ForEach(feedUsers) { user in
                            NavigationLink {
                                UserProfileView(userId: user.id)
                            } label: {
                                FeedUserRow(user: user, now: now)
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: network.isOnline)
            .refreshable {
                await refreshStudyState()
                await loadFeed()
            }
            .task {
                // Show last-known feed immediately (works offline)
                if feedUsers.isEmpty {
                    feedUsers = FeedCache.load()
                }
                await refreshStudyState()
                await loadFeed()
                await startPolling()
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
            .sheet(isPresented: $showComposePost) {
                ComposePostView(initialMinutes: composeInitialMinutes)
            }
        }
    }

    // MARK: - Study Card

    @ViewBuilder
    private var studyCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(isStudying ? .orange : .secondary)
                Text(isStudying ? elapsedString(from: studyStartedAt ?? now, to: now) : "--:--")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(isStudying ? .orange : .secondary)
                Spacer()
                Text(isStudying ? "Studying" : "Not Studying")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await toggleStudy() }
            } label: {
                Group {
                    if studyActionLoading {
                        ProgressView()
                            .tint(isStudying ? .white : .white)
                    } else {
                        Text(isStudying ? "Stop Studying" : "Start Studying")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(isStudying ? .red : .accentColor)
            .disabled(studyActionLoading)

            if let studyError {
                Text(studyError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
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

    // MARK: - Empty Feed

    private var emptyFeedSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Following Users")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("Find users in the Search tab")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Actions

    /// Reconcile the study state against the server. The server flag is the shared
    /// "studying" signal across devices; the device's local timer is what we measure
    /// with (seeded from the server for sessions started on another device).
    ///
    /// The local session always wins over the server, so quitting and relaunching
    /// the app never loses a running timer. The server can only *add* a session we
    /// don't have, or end one it knew about.
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
                // Began offline and was never announced. Publish it now — the
                // local start time is untouched, so the timer doesn't jump.
                do {
                    try await APIClient.startStudy()
                    LocalStudyStore.startedOffline = false
                } catch {
                    // Still unreachable; retried on the next refresh.
                }
            } else {
                // The server knew about this session and it's gone: ended on
                // another device, or past the server's 24h cutoff. Stop locally.
                LocalStudyStore.clear()
                isStudying = false
                studyStartedAt = nil
            }
        } else if status.isStudying {
            // Not studying locally but the server says we are (started on another
            // device): adopt it, seeding the timer from the server's start time.
            let start = status.startedAt ?? Date()
            LocalStudyStore.localStartedAt = start
            LocalStudyStore.startedOffline = false
            isStudying = true
            studyStartedAt = start
        } else {
            // Neither side is studying.
            isStudying = false
            studyStartedAt = nil
        }
    }

    /// Reflect the local session (used when offline / server unreachable).
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
        defer { isLoadingFeed = false }

        do {
            feedError = nil
            let response = try await APIClient.getHomeFeed()
            feedUsers = response.users
            FeedCache.save(response.users)
        } catch APIError.networkError {
            // Offline: keep showing cached feed, banner already indicates offline
            feedError = nil
        } catch {
            feedError = error.localizedDescription
        }
    }

    private func startPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Config.feedPollingInterval))
            await refreshStudyState()
            await loadFeed()
        }
    }

    private func toggleStudy() async {
        studyActionLoading = true
        studyError = nil
        defer { studyActionLoading = false }
        if isStudying {
            await stopStudying()
        } else {
            await startStudying()
        }
    }

    private func startStudying() async {
        // Start the local timer immediately (the device is the source of truth).
        let now = Date()
        LocalStudyStore.localStartedAt = now
        isStudying = true
        studyStartedAt = now

        // Report to the server (idempotent). If offline/failed, flag it for
        // delayed sending on the next reconnect.
        do {
            try await APIClient.startStudy()
            LocalStudyStore.startedOffline = false
        } catch {
            LocalStudyStore.startedOffline = true
        }
    }

    private func stopStudying() async {
        // Local timer is the truth; capture elapsed before clearing.
        let start = LocalStudyStore.localStartedAt ?? studyStartedAt
        LocalStudyStore.clear()
        isStudying = false
        studyStartedAt = nil

        // Clear the server flag when online. When offline we do nothing; the
        // server flag is reconciled (and can be turned off manually) on reconnect.
        if network.isOnline {
            try? await APIClient.stopStudy()
        }

        // Offer to post the just-finished session; prefill with elapsed minutes.
        if let start {
            let elapsed = Int(Date().timeIntervalSince(start) / 60)
            composeInitialMinutes = max(1, elapsed)
            showComposePost = true
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

// MARK: - Feed Row

struct FeedUserRow: View {
    let user: UserWithStudyStatus
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            UserIconView(
                emoji: user.iconEmoji,
                backgroundColor: user.iconBackgroundColor,
                size: 44,
                isStudying: user.isStudying
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.body)
                if user.isStudying {
                    HStack(spacing: 4) {
                        Text("Studying")
                        if let since = user.studyingSince {
                            Text("· \(studyingDurationString(since: since))")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                } else {
                    Text("Not Studying")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func studyingDurationString(since: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(since)))
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

#Preview {
    HomeView()
        .environment(AppState())
}
