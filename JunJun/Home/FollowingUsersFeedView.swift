import SwiftUI

struct FollowingUsersFeedView: View {
    let feedUsers: [UserWithStudyStatus]
    let hasLoadedFeed: Bool
    let isStudying: Bool
    let now: Date
    let onSelectUser: (String) -> Void

    @Environment(UserStore.self) private var userStore

    private var activeUsers: [UserWithStudyStatus] {
        feedUsers.compactMap { user in
            let live = userStore.user(for: user.id) ?? user
            if live.isFollowing == false {
                return nil
            }
            return live
        }
    }

    private struct BubbleConfig: Equatable {
        let isTop: Bool
        let extendsRight: Bool
    }

    private var bubbleConfigs: [String: BubbleConfig] {
        var configs: [String: BubbleConfig] = [:]
        var topOccupied: Set<Int> = []
        var bottomOccupied: Set<Int> = []

        let users = activeUsers
        for i in 0..<users.count {
            let user = users[i]
            guard user.isStudying,
                  let act = user.activity?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !act.isEmpty else {
                continue
            }

            let isTop = !topOccupied.contains(i)
            let leftNeighborHasBubble = (i > 0) && {
                let neighbor = users[i - 1]
                return neighbor.isStudying && !(neighbor.activity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }()

            let extendsRight: Bool
            if i > 0 && !leftNeighborHasBubble {
                let slotOccupied = isTop ? topOccupied.contains(i - 1) : bottomOccupied.contains(i - 1)
                extendsRight = slotOccupied
            } else {
                extendsRight = true
            }

            configs[user.id] = BubbleConfig(isTop: isTop, extendsRight: extendsRight)

            var occupied = isTop ? topOccupied : bottomOccupied
            occupied.insert(i)
            if FollowingActivityBubble.occupiesNeighbor(for: act) {
                if extendsRight {
                    occupied.insert(i + 1)
                } else if i > 0 {
                    occupied.insert(i - 1)
                }
            }
            if isTop {
                topOccupied = occupied
            } else {
                bottomOccupied = occupied
            }
        }

        return configs
    }

    private var hasAnyTopBubble: Bool { bubbleConfigs.values.contains { $0.isTop } }
    private var hasAnyBottomBubble: Bool { bubbleConfigs.values.contains { !$0.isTop } }

    private var followingTopPadding: CGFloat {
        isStudying ? (hasAnyTopBubble ? 18 : 30) : (hasAnyTopBubble ? 20 : 38)
    }

    var body: some View {
        if !hasLoadedFeed && activeUsers.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 117)
        } else if activeUsers.isEmpty {
            emptyFeedSection
        } else {
            followingSection
        }
    }

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(activeUsers) { user in
                        let config = bubbleConfigs[user.id]
                        let isSingle = user.activity.map { FollowingActivityBubble.isSingleCell(for: $0) } ?? true
                        let alignment: Alignment = isSingle ? .center : ((config?.extendsRight ?? true) ? .leading : .trailing)
                        let offsetX: CGFloat = isSingle ? 0 : ((config?.extendsRight ?? true) ? 2.5 : -2.5)
                        let userColor = Color(hex: user.iconBackgroundColor) ?? .orange

                        Button {
                            onSelectUser(user.id)
                        } label: {
                            VStack(spacing: 0) {
                                bubbleSlot(for: user, isTop: true, config: config, alignment: alignment, offsetX: offsetX, color: userColor)

                                UserIconView(
                                    emoji: user.iconEmoji,
                                    backgroundColor: user.iconBackgroundColor,
                                    size: 52,
                                    isStudying: user.isStudying,
                                    isPro: user.isPro ?? false
                                )
                                Text(user.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.top, 8)

                                studyTimeLabel(for: user)

                                bubbleSlot(for: user, isTop: false, config: config, alignment: alignment, offsetX: offsetX, color: userColor)
                            }
                            .frame(width: 74)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, followingTopPadding)
                .padding(.bottom, hasAnyBottomBubble ? 8 : 12)
                .animation(.easeInOut(duration: 0.25), value: hasAnyTopBubble)
                .animation(.easeInOut(duration: 0.25), value: hasAnyBottomBubble)
                .animation(.easeInOut(duration: 0.25), value: isStudying)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func bubbleSlot(for user: UserWithStudyStatus, isTop: Bool, config: BubbleConfig?, alignment: Alignment, offsetX: CGFloat, color: Color) -> some View {
        let shouldShow = isTop ? hasAnyTopBubble : hasAnyBottomBubble
        if shouldShow {
            ZStack(alignment: alignment) {
                if let config, config.isTop == isTop, let act = user.activity {
                    FollowingActivityBubble(
                        text: act,
                        isTop: isTop,
                        extendsRight: config.extendsRight,
                        tintColor: color
                    )
                    .offset(x: offsetX)
                }
            }
            .frame(width: 74, height: 36, alignment: alignment)
            .padding(isTop ? .bottom : .top, isTop ? 14 : 2)
        }
    }

    @ViewBuilder
    private func studyTimeLabel(for user: UserWithStudyStatus) -> some View {
        Group {
            if user.isStudying {
                if user.isPaused == true {
                    Text(HomeTimeFormatter.formatElapsed(seconds: Double(user.accumulatedSeconds ?? 0)))
                        .foregroundStyle(.secondary)
                } else if let since = user.studyingSince {
                    Text(HomeTimeFormatter.elapsedString(from: since, to: now))
                        .foregroundStyle(.orange)
                } else {
                    Text(" ")
                }
            } else {
                Text(" ")
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .padding(.top, 2)
    }

    private var emptyFeedSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Following Users")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Find people to follow in the Search tab")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 117)
    }
}
