import Foundation

// MARK: - Auth

struct SendOTPRequest: Encodable {
    let email: String
    let type: String = "sign-in"
}

struct VerifyOTPRequest: Encodable {
    let email: String
    let otp: String
}

// MARK: - User

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let iconEmoji: String
    let iconBackgroundColor: String
}

struct UserWithFollowStatus: Codable, Identifiable {
    let id: String
    let username: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool
}

struct UserWithStudyStatus: Codable, Identifiable {
    let id: String
    let username: String
    let iconEmoji: String
    let iconBackgroundColor: String
    var isFollowing: Bool?
    let isStudying: Bool
    let studyingSince: Date?
}

// MARK: - Study Session

struct StudySession: Codable {
    let id: String
    let startedAt: Date
    let endedAt: Date?
}

struct MyStudyStatus: Codable {
    let isStudying: Bool
    let startedAt: Date?
}

// MARK: - Home Feed

struct HomeFeedResponse: Codable {
    let users: [UserWithStudyStatus]
}

// MARK: - Following

struct FollowingResponse: Codable {
    let users: [UserProfile]
}

struct FollowActionResponse: Codable {
    let isFollowing: Bool
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

struct CreateProfileRequest: Encodable {
    let username: String
    let iconEmoji: String
    let iconBackgroundColor: String
}

struct UpdateProfileRequest: Encodable {
    let username: String?
    let iconEmoji: String?
    let iconBackgroundColor: String?
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

struct EmptyResponse: Decodable {}
