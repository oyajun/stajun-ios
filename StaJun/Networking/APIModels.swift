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
}

struct UserWithFollowStatus: Codable, Identifiable {
    let id: String
    let name: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool
}

struct UserWithStudyStatus: Codable, Identifiable {
    let id: String
    let name: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool?
    let isStudying: Bool
    let studyingSince: Date?
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

// MARK: - Following

struct FollowActionResponse: Codable {
    let isFollowing: Bool
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
struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let minutes: Int
    let comment: String?
    let createdAt: Date
    let user: UserProfile
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

struct StatsResponse: Decodable {
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

struct StatsSeriesResponse: Decodable {
    let userId: String
    let unit: String
    let from: String
    let to: String
    let totalMinutes: Int
    let buckets: [StatsBucket]
}

struct StatsBucket: Decodable, Identifiable {
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

