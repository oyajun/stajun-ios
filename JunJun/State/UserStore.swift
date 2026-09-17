import Foundation
import SwiftUI

/// ユーザー情報（プロフィール、フォロー状況、学習ステータスなど）をメモリ上で一元管理するストア。
/// 画面を跨いでも即座に最新状態が同期される Single Source of Truth (SSOT) として機能します。
@MainActor
@Observable
final class UserStore {
    static let shared = UserStore()

    /// メモリ上で保持するユーザー情報辞書 [userId: UserWithStudyStatus]
    private(set) var users: [String: UserWithStudyStatus] = [:]

    init() {}

    /// 指定したユーザーIDの最新情報を取得（メモリ上のキャッシュを高速に返す）
    func user(for id: String) -> UserWithStudyStatus? {
        users[id]
    }

    /// UserWithStudyStatus の登録・マージ
    func upsert(_ incoming: UserWithStudyStatus) {
        if let existing = users[incoming.id] {
            let merged = UserWithStudyStatus(
                id: incoming.id,
                name: incoming.name.isEmpty ? existing.name : incoming.name,
                iconEmoji: incoming.iconEmoji.isEmpty ? existing.iconEmoji : incoming.iconEmoji,
                iconBackgroundColor: incoming.iconBackgroundColor.isEmpty ? existing.iconBackgroundColor : incoming.iconBackgroundColor,
                isFollowing: incoming.isFollowing ?? existing.isFollowing,
                muteStudyStartNotification: incoming.muteStudyStartNotification ?? existing.muteStudyStartNotification,
                isMuted: incoming.isMuted ?? existing.isMuted,
                isStudying: incoming.isStudying,
                studyingSince: incoming.isStudying ? (incoming.studyingSince ?? existing.studyingSince) : nil,
                isPaused: incoming.isPaused ?? existing.isPaused,
                accumulatedSeconds: incoming.accumulatedSeconds ?? existing.accumulatedSeconds,
                isPro: incoming.isPro ?? existing.isPro,
                activity: incoming.activity ?? existing.activity
            )
            users[incoming.id] = merged
            UserProfileCache.save(merged, userId: incoming.id)
        } else {
            users[incoming.id] = incoming
            UserProfileCache.save(incoming, userId: incoming.id)
        }
    }

    /// 複数件の UserWithStudyStatus を一括登録・マージ
    func upsert(_ incomingList: [UserWithStudyStatus]) {
        for item in incomingList {
            upsert(item)
        }
    }

    /// UserWithFollowStatus の登録・マージ
    func upsert(_ incoming: UserWithFollowStatus) {
        if let existing = users[incoming.id] {
            let isStudying = incoming.isStudying ?? existing.isStudying
            let studyingSince = isStudying ? (incoming.studyingSince ?? existing.studyingSince) : nil
            let merged = UserWithStudyStatus(
                id: incoming.id,
                name: incoming.name.isEmpty ? existing.name : incoming.name,
                iconEmoji: incoming.iconEmoji.isEmpty ? existing.iconEmoji : incoming.iconEmoji,
                iconBackgroundColor: incoming.iconBackgroundColor.isEmpty ? existing.iconBackgroundColor : incoming.iconBackgroundColor,
                isFollowing: incoming.isFollowing,
                muteStudyStartNotification: incoming.muteStudyStartNotification ?? existing.muteStudyStartNotification,
                isMuted: incoming.isMuted ?? existing.isMuted,
                isStudying: isStudying,
                studyingSince: studyingSince,
                isPaused: existing.isPaused,
                accumulatedSeconds: existing.accumulatedSeconds,
                isPro: incoming.isPro ?? existing.isPro,
                activity: incoming.activity ?? existing.activity
            )
            users[incoming.id] = merged
            UserProfileCache.save(merged, userId: incoming.id)
        } else {
            let newStatus = UserWithStudyStatus(
                id: incoming.id,
                name: incoming.name,
                iconEmoji: incoming.iconEmoji,
                iconBackgroundColor: incoming.iconBackgroundColor,
                isFollowing: incoming.isFollowing,
                muteStudyStartNotification: incoming.muteStudyStartNotification,
                isMuted: incoming.isMuted,
                isStudying: incoming.isStudying ?? false,
                studyingSince: incoming.studyingSince,
                isPaused: false,
                accumulatedSeconds: nil,
                isPro: incoming.isPro,
                activity: incoming.activity
            )
            users[incoming.id] = newStatus
            UserProfileCache.save(newStatus, userId: incoming.id)
        }
    }

    /// 複数件の UserWithFollowStatus を一括登録・マージ
    func upsert(_ incomingList: [UserWithFollowStatus]) {
        for item in incomingList {
            upsert(item)
        }
    }

    /// UserProfile の登録・マージ
    func upsert(_ profile: UserProfile) {
        if let existing = users[profile.id] {
            let merged = UserWithStudyStatus(
                id: profile.id,
                name: profile.name.isEmpty ? existing.name : profile.name,
                iconEmoji: profile.iconEmoji.isEmpty ? existing.iconEmoji : profile.iconEmoji,
                iconBackgroundColor: profile.iconBackgroundColor.isEmpty ? existing.iconBackgroundColor : profile.iconBackgroundColor,
                isFollowing: existing.isFollowing,
                muteStudyStartNotification: existing.muteStudyStartNotification,
                isMuted: existing.isMuted,
                isStudying: existing.isStudying,
                studyingSince: existing.studyingSince,
                isPaused: existing.isPaused,
                accumulatedSeconds: existing.accumulatedSeconds,
                isPro: profile.isPro ?? existing.isPro,
                activity: existing.activity
            )
            users[profile.id] = merged
            UserProfileCache.save(merged, userId: profile.id)
        } else {
            let newStatus = UserWithStudyStatus(
                id: profile.id,
                name: profile.name,
                iconEmoji: profile.iconEmoji,
                iconBackgroundColor: profile.iconBackgroundColor,
                isFollowing: nil,
                muteStudyStartNotification: nil,
                isMuted: nil,
                isStudying: false,
                studyingSince: nil,
                isPaused: nil,
                accumulatedSeconds: nil,
                isPro: profile.isPro,
                activity: nil
            )
            users[profile.id] = newStatus
        }
    }

    /// フォロー状態を更新
    func setFollowing(userId: String, isFollowing: Bool, isMuted: Bool? = nil, muteNotification: Int? = nil) {
        var u = users[userId] ?? UserProfileCache.load(userId: userId) ?? UserWithStudyStatus(
            id: userId,
            name: "",
            iconEmoji: "👤",
            iconBackgroundColor: "#CCCCCC",
            isFollowing: isFollowing,
            isStudying: false
        )
        u.isFollowing = isFollowing
        if let isMuted {
            u.isMuted = isMuted
        } else if !isFollowing {
            u.isMuted = false
        }
        if let muteNotification {
            u.muteStudyStartNotification = muteNotification
        } else if !isFollowing {
            u.muteStudyStartNotification = 0
        }
        users[userId] = u
        UserProfileCache.save(u, userId: userId)
    }

    /// ミュート状態を更新
    func setMuted(userId: String, isMuted: Bool, muteNotification: Int? = nil) {
        guard var u = users[userId] ?? UserProfileCache.load(userId: userId) else { return }
        u.isMuted = isMuted
        u.muteStudyStartNotification = muteNotification ?? (isMuted ? 1 : 0)
        users[userId] = u
        UserProfileCache.save(u, userId: userId)
    }

    /// 学習ステータスを更新
    func setStudyStatus(
        userId: String,
        isStudying: Bool,
        studyingSince: Date? = nil,
        isPaused: Bool? = nil,
        accumulatedSeconds: Int? = nil,
        activity: String? = nil
    ) {
        guard let u = users[userId] ?? UserProfileCache.load(userId: userId) else { return }
        let merged = UserWithStudyStatus(
            id: u.id,
            name: u.name,
            iconEmoji: u.iconEmoji,
            iconBackgroundColor: u.iconBackgroundColor,
            isFollowing: u.isFollowing,
            muteStudyStartNotification: u.muteStudyStartNotification,
            isMuted: u.isMuted,
            isStudying: isStudying,
            studyingSince: isStudying ? (studyingSince ?? u.studyingSince) : nil,
            isPaused: isPaused ?? u.isPaused,
            accumulatedSeconds: accumulatedSeconds ?? u.accumulatedSeconds,
            isPro: u.isPro,
            activity: activity ?? u.activity
        )
        users[userId] = merged
        UserProfileCache.save(merged, userId: userId)
    }

    /// プロフィール情報（名前、アイコンなど）を更新
    func updateProfile(
        userId: String,
        name: String? = nil,
        iconEmoji: String? = nil,
        iconBackgroundColor: String? = nil,
        isPro: Bool? = nil
    ) {
        guard let u = users[userId] ?? UserProfileCache.load(userId: userId) else { return }
        let merged = UserWithStudyStatus(
            id: u.id,
            name: name ?? u.name,
            iconEmoji: iconEmoji ?? u.iconEmoji,
            iconBackgroundColor: iconBackgroundColor ?? u.iconBackgroundColor,
            isFollowing: u.isFollowing,
            muteStudyStartNotification: u.muteStudyStartNotification,
            isMuted: u.isMuted,
            isStudying: u.isStudying,
            studyingSince: u.studyingSince,
            isPaused: u.isPaused,
            accumulatedSeconds: u.accumulatedSeconds,
            isPro: isPro ?? u.isPro,
            activity: u.activity
        )
        users[userId] = merged
        UserProfileCache.save(merged, userId: userId)
    }

    /// メモリ上のキャッシュをクリア（サインアウト・アカウント削除時など）
    func clear() {
        users.removeAll()
    }
}
