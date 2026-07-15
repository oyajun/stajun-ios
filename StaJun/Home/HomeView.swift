import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AppState.self) private var appState

    // 自分の学習状態
    @State private var isStudying = false
    @State private var studyStartedAt: Date?
    @State private var studyActionLoading = false
    @State private var studyError: String?

    // フィード
    @State private var feedUsers: [UserWithStudyStatus] = []
    @State private var feedError: String?

    // タイマー（経過時間表示）
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            List {
                // 勉強開始/終了カード（Liquid Glass）
                studyCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                // フォロー中ユーザー一覧
                if feedUsers.isEmpty {
                    emptyFeedSection
                } else {
                    Section("フォロー中") {
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
            .navigationTitle("ホーム")
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
                    Text("勉強中")
                        .font(.footnote)
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
                            isStudying ? "勉強を終わる" : "勉強を始める",
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
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty Feed

    private var emptyFeedSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("フォロー中のユーザーがいません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("検索タブからユーザーを見つけましょう")
                    .font(.caption)
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
            // サイレントに失敗（画面はデフォルト値で表示）
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
            studyError = "すでに勉強中です"
        } catch APIError.notFound {
            studyError = "アクティブなセッションがありません"
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
                    Text("勉強中")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("休憩中")
                        .font(.caption)
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
