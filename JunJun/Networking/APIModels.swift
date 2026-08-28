import Foundation

// MARK: - Auth

struct SendOTPRequest: Encodable {
    let email: String
    var type: String = "sign-in"
}

struct VerifyOTPRequest: Encodable {
    let email: String
    let otp: String
}

struct ChangeEmailRequest: Encodable {
    let newEmail: String
    let otp: String
}

struct RequestEmailChangeRequest: Encodable {
    let newEmail: String
}

// MARK: - User

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let iconEmoji: String
    let iconBackgroundColor: String
    let isAnonymous: Bool?
    let email: String?
    let isPro: Bool?

    init(id: String, name: String, iconEmoji: String, iconBackgroundColor: String, isAnonymous: Bool? = nil, email: String? = nil, isPro: Bool? = nil) {
        self.id = id
        self.name = name
        self.iconEmoji = iconEmoji
        self.iconBackgroundColor = iconBackgroundColor
        self.isAnonymous = isAnonymous
        self.email = email
        self.isPro = isPro
    }
}

struct UserWithFollowStatus: Codable, Identifiable {
    let id: String
    let name: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool
    var muteStudyStartNotification: Int?
    var isMuted: Bool?
    let isStudying: Bool?
    let studyingSince: Date?
    let isPro: Bool?
}


struct UserWithStudyStatus: Codable, Identifiable {
    let id: String
    let name: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool?
    var muteStudyStartNotification: Int?
    var isMuted: Bool?
    let isStudying: Bool
    let studyingSince: Date?
    let isPro: Bool?
}

// MARK: - Pro Subscription

struct SyncProStatusRequest: Encodable {
    let isPro: Bool
    let proExpiresAt: String?
}

struct SyncProStatusResponse: Codable {
    let id: String
    let isPro: Bool
    let proExpiresAt: String?
}

// MARK: - Study Session

struct MyStudyStatus: Codable {
    let isStudying: Bool
    let startedAt: Date?
}

// MARK: - Home Feed

struct HomeFeedResponse: Codable {
    let users: [UserWithStudyStatus]
}

// MARK: - Polling

struct PollingResponse: Codable {
    let unreadCount: Int
    let unreadNotificationCount: Int?
    let users: [UserWithStudyStatus]
    let studySession: MyStudyStatus
}

// MARK: - Following

struct FollowActionResponse: Codable {
    let isFollowing: Bool
    let muteStudyStartNotification: Int?
    let isMuted: Bool?
}

struct MuteActionResponse: Codable {
    let muteStudyStartNotification: Int?
    let isMuted: Bool?
}

// MARK: - Posts (機能2: 学習時間の投稿)

/// Request body for POST /api/v1/posts
struct CreatePostRequest: Encodable {
    let minutes: Int
    let comment: String?
}

/// Response of POST /api/v1/posts (a newly created study-time post)
struct StudyPost: Codable, Identifiable {
    let id: String
    let minutes: Int
    let comment: String?
    let createdAt: Date
}

/// A timeline post, including its author summary. Used by GET /api/v1/posts.
struct Post: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let minutes: Int
    let comment: String?
    let createdAt: Date
    let user: UserProfile
    var likeCount: Int
    var isLiked: Bool

    init(
        id: String,
        userId: String,
        minutes: Int,
        comment: String?,
        createdAt: Date,
        user: UserProfile,
        likeCount: Int = 0,
        isLiked: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.minutes = minutes
        self.comment = comment
        self.createdAt = createdAt
        self.user = user
        self.likeCount = likeCount
        self.isLiked = isLiked
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, minutes, comment, createdAt, user, likeCount, isLiked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        minutes = try container.decode(Int.self, forKey: .minutes)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        user = try container.decode(UserProfile.self, forKey: .user)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }
}

/// Response of POST/DELETE /api/v1/posts/:id/like
struct LikePostResponse: Codable {
    let likeCount: Int
    let isLiked: Bool
}

/// Cursor-paginated list of posts
struct PostsResponse: Codable {
    let posts: [Post]
    let nextCursor: String?
}

// MARK: - Search

struct SearchResponse: Codable {
    let users: [UserWithFollowStatus]
    let pagination: Pagination
}

struct RecommendedUsersResponse: Codable {
    let users: [UserWithStudyStatus]
}

struct Pagination: Codable {

    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Profile

struct UpdateProfileRequest: Encodable {
    let name: String?
    let iconEmoji: String?
    let iconBackgroundColor: String?
}

// MARK: - Stats

struct StatsResponse: Codable {
    let userId: String
    let totalMinutes: Int
    let todayMinutes: Int
    let weekMinutes: Int
    let monthMinutes: Int
    let today: String
    let weekStart: String
    let monthStart: String
    let firstPostDate: String?
}

struct StatsSeriesResponse: Codable {
    let userId: String
    let unit: String
    let from: String
    let to: String
    let totalMinutes: Int
    let buckets: [StatsBucket]
}

struct StatsBucket: Codable, Identifiable {
    let start: String
    let end: String
    let minutes: Int
    var id: String { start }
}

// MARK: - Error

struct APIErrorResponse: Decodable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Decodable {
    let code: String
    let message: String
}

// MARK: - Internal

struct EmptyRequest: Encodable {}
struct EmptyResponse: Decodable {}

// MARK: - Block

struct BlockedUsersResponse: Codable {
    let users: [UserWithFollowStatus]
    let pagination: Pagination
}

// MARK: - Notifications

struct AppNotification: Codable, Identifiable {
    let id: String
    let type: String
    let actor: UserProfile?
    let postId: String?
    let extra: String?
    var isRead: Bool
    let createdAt: Date
}

struct NotificationsResponse: Codable {
    let notifications: [AppNotification]
    let unreadCount: Int
    let nextCursor: String?
}

struct UnreadNotificationCountResponse: Codable {
    let unreadCount: Int
}

// MARK: - Push Notification Settings

struct PushNotificationSettings: Codable, Equatable {
    var enabled: Bool
    var follow: Bool
    var studyStart: Bool
}

struct UpdatePushNotificationSettingsRequest: Encodable {
    let enabled: Bool?
    let follow: Bool?
    let studyStart: Bool?
}

