import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    // Study status — initialise from local store so the border appears immediately on launch
    @State private var isStudying = LocalStudyStore.localStartedAt != nil
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

    // Own profile navigation
    @State private var showOwnProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Offline banner
                    if !network.isOnline {
                        offlineBanner
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Study start/stop card
                    studyCard
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    Divider()
                        .padding(.horizontal, 32)

                    // Following users horizontal scroll
                    if feedUsers.isEmpty {
                        emptyFeedSection
                    } else {
                        followingSection
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
            .onChange(of: isStudying) { _, newValue in
                appState.isStudying = newValue
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
            .navigationDestination(isPresented: $showOwnProfile) {
                if let userId = appState.currentUser?.id {
                    UserProfileView(userId: userId)
                }
            }
        }
    }

    // MARK: - Study Card

    @ViewBuilder
    private var studyCard: some View {
        HStack(alignment: .bottom, spacing: 40) {
            // Left: own icon + name (fluffy animation tied to local isStudying)
            Button {
                showOwnProfile = true
            } label: {
                VStack(spacing: 0) {
                    UserIconView(
                        emoji: appState.currentUser?.iconEmoji ?? "📚",
                        backgroundColor: appState.currentUser?.iconBackgroundColor ?? "#FFD54F",
                        size: 52,
                        isStudying: isStudying
                    )
                    Spacer(minLength: 0)
                    Text(appState.currentUser?.username ?? "")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            // Right: timer + button
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

    // MARK: - Following Section

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Following")
                .font(.headline)
                .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(feedUsers) { user in
                        NavigationLink {
                            UserProfileView(userId: user.id)
                        } label: {
                            VStack(spacing: 2) {
                                UserIconView(
                                    emoji: user.iconEmoji,
                                    backgroundColor: user.iconBackgroundColor,
                                    size: 52,
                                    isStudying: user.isStudying
                                )
                                Text(user.username)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if user.isStudying, let since = user.studyingSince {
                                    Text(elapsedString(from: since, to: now))
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundStyle(.orange)
                                } else {
                                    Text(" ")
                                        .font(.caption2)
                                }
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 32)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Empty Feed

    private var emptyFeedSection: some View {
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
        .padding(.vertical, 48)
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
        studyError = nil
        if isStudying {
            stopStudying()
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

    private func stopStudying() {
        // Local timer is the truth; capture elapsed before clearing.
        let start = LocalStudyStore.localStartedAt ?? studyStartedAt
        LocalStudyStore.clear()
        isStudying = false
        studyStartedAt = nil

        // Show the post composer immediately before the server call completes.
        if let start {
            let elapsed = Int(Date().timeIntervalSince(start) / 60)
            composeInitialMinutes = max(1, elapsed)
            showComposePost = true
        }

        // Notify the server in the background; offline case is reconciled on reconnect.
        if network.isOnline {
            Task { try? await APIClient.stopStudy() }
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

#Preview {
    HomeView()
        .environment(AppState())
}
