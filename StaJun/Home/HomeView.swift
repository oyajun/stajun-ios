import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AppState.self) private var appState

    // Study status
    @State private var isStudying = false
    @State private var studyStartedAt: Date?
    @State private var studyActionLoading = false
    @State private var studyError: String?

    // Feed
    @State private var feedUsers: [UserWithStudyStatus] = []
    @State private var feedError: String?

    // Timer (elapsed time display)
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            List {
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
                                FeedUserRow(user: user)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .refreshable {
                await loadFeed()
            }
            .task {
                await loadMyStatus()
                await loadFeed()
                await startPolling()
            }
            .onReceive(
                Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            ) { _ in
                now = Date()
            }
        }
    }

    // MARK: - Study Card

    @ViewBuilder
    private var studyCard: some View {
        VStack(spacing: 12) {
            if isStudying, let start = studyStartedAt {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text(elapsedString(from: start, to: now))
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Studying")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await toggleStudy() }
            } label: {
                Group {
                    if studyActionLoading {
                        ProgressView()
                            .tint(isStudying ? .white : .white)
                    } else {
                        Label(
                            isStudying ? "Stop Studying" : "Start Studying",
                            systemImage: isStudying ? "stop.fill" : "play.fill"
                        )
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
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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

    private func loadMyStatus() async {
        do {
            let status = try await APIClient.getMyStudyStatus()
            isStudying = status.isStudying
            studyStartedAt = status.startedAt
        } catch {
            // Silent failure (screen shows default values)
        }
    }

    private func loadFeed() async {
        do {
            feedError = nil
            let response = try await APIClient.getHomeFeed()
            feedUsers = response.users
        } catch {
            feedError = error.localizedDescription
        }
    }

    private func startPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Config.feedPollingInterval))
            await loadFeed()
        }
    }

    private func toggleStudy() async {
        studyActionLoading = true
        studyError = nil
        defer { studyActionLoading = false }
        do {
            if isStudying {
                _ = try await APIClient.stopStudy()
                isStudying = false
                studyStartedAt = nil
            } else {
                let session = try await APIClient.startStudy()
                isStudying = true
                studyStartedAt = session.startedAt
            }
        } catch APIError.conflict {
            studyError = "Already studying"
        } catch APIError.notFound {
            studyError = "No active session"
        } catch {
            studyError = error.localizedDescription
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
                    Text("Studying")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    Text("On Break")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
