import Foundation

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case unauthorized
    case onboardingRequired
    case sessionNotFresh
    case forbidden(code: String, message: String)
    case notFound
    case conflict(code: String, message: String)
    case badRequest(code: String, message: String)
    case serverError(code: String, message: String)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Login is required."
        case .onboardingRequired:
            return "Profile setup is required."
        case .sessionNotFresh:
            return "Session has expired. Please re-authenticate."
        case .forbidden(_, let msg):
            return msg
        case .notFound:
            return "Not found."
        case .conflict(_, let msg):
            return msg
        case .badRequest(_, let msg):
            return msg
        case .serverError(_, let msg):
            return msg
        case .networkError(let e):
            return e.localizedDescription
        case .decodingError(let e):
            return "Failed to parse data: \(e.localizedDescription)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Client

enum APIClient {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Always send timestamps to the server as UTC (ISO8601 uses "Z").
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: Low-level

    private static func buildRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil
    ) throws -> URLRequest {
        let url = URL(string: path, relativeTo: Config.baseURL)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        // Fail reasonably fast instead of hanging on the default 60s timeout.
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set Origin header for better-auth CSRF protection (remove trailing slash)
        var origin = Config.baseURL.absoluteString
        if origin.hasSuffix("/") {
            origin = String(origin.dropLast())
        }
        req.setValue(origin, forHTTPHeaderField: "Origin")
        
        if let token = KeychainHelper.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    /// Decode response body to T. Throws APIError for 4xx/5xx.
    @discardableResult
    private static func perform<T: Decodable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        as type: T.Type = EmptyResponse.self as! T.Type
    ) async throws -> T {
        let req = try buildRequest(path: path, method: method, body: body)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        let http = response as! HTTPURLResponse

        // Auto-save Bearer token from header
        if let token = http.value(forHTTPHeaderField: "set-auth-token"), !token.isEmpty {
            KeychainHelper.token = token
        }

        if http.statusCode >= 400 {
            let parsed = try? decoder.decode(APIErrorResponse.self, from: data)
            let code = parsed?.error.code ?? "UNKNOWN"
            let message = parsed?.error.message ?? "An error occurred."
            switch http.statusCode {
            case 401: throw APIError.unauthorized
            case 403:
                switch code {
                case "ONBOARDING_REQUIRED": throw APIError.onboardingRequired
                case "SESSION_NOT_FRESH": throw APIError.sessionNotFresh
                default: throw APIError.forbidden(code: code, message: message)
                }
            case 404: throw APIError.notFound
            case 409: throw APIError.conflict(code: code, message: message)
            case 400: throw APIError.badRequest(code: code, message: message)
            default: throw APIError.serverError(code: code, message: message)
            }
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth

    /// Send OTP email
    static func sendOTP(email: String) async throws {
        try await perform(path: "/api/auth/email-otp/send-verification-otp", method: "POST", body: SendOTPRequest(email: email), as: EmptyResponse.self)
    }

    /// Sign in with OTP (set-auth-token auto-saved to Keychain)
    static func signIn(email: String, otp: String) async throws {
        try await perform(path: "/api/auth/sign-in/email-otp", method: "POST", body: VerifyOTPRequest(email: email, otp: otp), as: EmptyResponse.self)
    }

    /// Sign out (caller must delete token from Keychain)
    static func signOut() async throws {
        try await perform(path: "/api/auth/sign-out", method: "POST", as: EmptyResponse.self)
    }

    // MARK: - Profile

    /// Get my profile
    static func getMyProfile() async throws -> UserProfile {
        try await perform(path: "/api/v1/users/me", method: "GET", as: UserProfile.self)
    }

    /// Create profile (onboarding)
    static func createProfile(username: String, iconEmoji: String, iconBackgroundColor: String) async throws -> UserProfile {
        let body = CreateProfileRequest(username: username, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        return try await perform(path: "/api/v1/users/me", method: "POST", body: body, as: UserProfile.self)
    }

    /// Update profile (partial update)
    static func updateProfile(username: String? = nil, iconEmoji: String? = nil, iconBackgroundColor: String? = nil) async throws -> UserProfile {
        let body = UpdateProfileRequest(username: username, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        return try await perform(path: "/api/v1/users/me", method: "PATCH", body: body, as: UserProfile.self)
    }

    /// Delete account (fresh session required)
    static func deleteAccount() async throws {
        try await perform(path: "/api/v1/users/me", method: "DELETE", as: EmptyResponse.self)
    }

    // MARK: - Users

    /// Get user profile by ID
    static func getUser(id: String) async throws -> UserWithStudyStatus {
        try await perform(path: "/api/v1/users/\(id)", method: "GET", as: UserWithStudyStatus.self)
    }

    /// Search users
    static func searchUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> SearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await perform(path: "/api/v1/users?q=\(encoded)&limit=\(limit)&offset=\(offset)", method: "GET", as: SearchResponse.self)
    }

    // MARK: - Follow

    /// Follow a user
    static func follow(userId: String) async throws -> FollowActionResponse {
        try await perform(path: "/api/v1/follow/\(userId)", method: "PUT", as: FollowActionResponse.self)
    }

    /// Unfollow a user
    static func unfollow(userId: String) async throws {
        try await perform(path: "/api/v1/follow/\(userId)", method: "DELETE", as: EmptyResponse.self)
    }

    /// Get the users that a given user follows (with studying flags). Pass "me" for the current user.
    static func getFollowing(userId: String = "me") async throws -> HomeFeedResponse {
        try await perform(path: "/api/v1/following/\(userId)", method: "GET", as: HomeFeedResponse.self)
    }

    /// Get the followers of a given user (with studying flags). Pass "me" for the current user.
    static func getFollowers(userId: String = "me") async throws -> HomeFeedResponse {
        try await perform(path: "/api/v1/followers/\(userId)", method: "GET", as: HomeFeedResponse.self)
    }

    // MARK: - Study Sessions

    /// Get my current study status
    static func getMyStudyStatus() async throws -> MyStudyStatus {
        try await perform(path: "/api/v1/study-sessions/me", method: "GET", as: MyStudyStatus.self)
    }

    /// Start studying. Idempotent upsert on the server (the server flag is only
    /// an approximate signal for others; the device holds the real timer).
    static func startStudy() async throws {
        try await perform(path: "/api/v1/study-sessions/start", method: "POST", as: EmptyResponse.self)
    }

    /// Stop studying. Clears the server flag (idempotent).
    static func stopStudy() async throws {
        try await perform(path: "/api/v1/study-sessions/stop", method: "POST", as: EmptyResponse.self)
    }

    // MARK: - Home Feed

    /// Get home feed (my following users with studying flags, for polling).
    /// Merged into the unified GET /following/me endpoint.
    static func getHomeFeed() async throws -> HomeFeedResponse {
        try await getFollowing(userId: "me")
    }

    // MARK: - Posts (Study Time Posts)

    /// Create a study-time post. Study time is entered manually (minutes),
    /// independent of live study sessions.
    static func createPost(minutes: Int, comment: String?) async throws -> StudyPost {
        // The API disallows control characters (incl. line breaks) in comments,
        // so collapse newlines to spaces before trimming.
        let sanitized = comment?
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = CreatePostRequest(
            minutes: minutes,
            comment: (sanitized?.isEmpty ?? true) ? nil : sanitized
        )
        return try await perform(path: "/api/v1/posts", method: "POST", body: body, as: StudyPost.self)
    }

    /// Home timeline (own + following users' posts).
    static func getTimeline(cursor: String? = nil, limit: Int = 20) async throws -> PostsResponse {
        try await perform(path: postsPath(userId: nil, cursor: cursor, limit: limit), method: "GET", as: PostsResponse.self)
    }

    /// Posts by a specific user (public, viewable even without following). Pass "me" for own posts.
    static func getUserPosts(userId: String, cursor: String? = nil, limit: Int = 20) async throws -> PostsResponse {
        try await perform(path: postsPath(userId: userId, cursor: cursor, limit: limit), method: "GET", as: PostsResponse.self)
    }

    /// Delete own post.
    static func deletePost(id: String) async throws {
        try await perform(path: "/api/v1/posts/\(id)", method: "DELETE", as: EmptyResponse.self)
    }

    /// Build a GET /api/v1/posts path with optional userId filter and cursor.
    private static func postsPath(userId: String?, cursor: String?, limit: Int) -> String {
        var query = ["limit=\(limit)"]
        if let userId {
            query.append("userId=\(userId)")
        }
        if let cursor, let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query.append("cursor=\(encoded)")
        }
        return "/api/v1/posts?" + query.joined(separator: "&")
    }

    // MARK: - Stats

    /// Summary stats for a user (total, today, week, month).
    static func getStats(userId: String = "me") async throws -> StatsResponse {
        return try await perform(path: "/api/v1/stats?userId=\(userId)&tz=\(tzOffset())", method: "GET", as: StatsResponse.self)
    }

    /// Time-series stats bucketed by day/week/month/year.
    static func getStatsSeries(userId: String = "me", unit: String, from: String, to: String) async throws -> StatsSeriesResponse {
        return try await perform(
            path: "/api/v1/stats/series?userId=\(userId)&tz=\(tzOffset())&unit=\(unit)&from=\(from)&to=\(to)",
            method: "GET",
            as: StatsSeriesResponse.self
        )
    }

    /// Returns the device's UTC offset percent-encoded for query strings (e.g. "%2B09:00").
    /// + must be encoded as %2B because bare + is decoded as a space by URL parsers.
    private static func tzOffset() -> String {
        let seconds = TimeZone.current.secondsFromGMT()
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "%2B" : "-"
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }
}
