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
        JSONEncoder()
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
        return try await perform(path: "/api/v1/users/search?q=\(encoded)&limit=\(limit)&offset=\(offset)", method: "GET", as: SearchResponse.self)
    }

    // MARK: - Follow

    /// Follow a user
    static func follow(userId: String) async throws -> FollowActionResponse {
        try await perform(path: "/api/v1/users/\(userId)/follow", method: "POST", as: FollowActionResponse.self)
    }

    /// Unfollow a user
    static func unfollow(userId: String) async throws {
        try await perform(path: "/api/v1/users/\(userId)/follow", method: "DELETE", as: EmptyResponse.self)
    }

    /// Get following list
    static func getFollowing() async throws -> FollowingResponse {
        try await perform(path: "/api/v1/me/following", method: "GET", as: FollowingResponse.self)
    }

    // MARK: - Study Sessions

    /// Get my current study status
    static func getMyStudyStatus() async throws -> MyStudyStatus {
        try await perform(path: "/api/v1/study-sessions/me", method: "GET", as: MyStudyStatus.self)
    }

    /// Start studying
    static func startStudy() async throws -> StudySession {
        try await perform(path: "/api/v1/study-sessions/start", method: "POST", as: StudySession.self)
    }

    /// Stop studying
    static func stopStudy() async throws -> StudySession {
        try await perform(path: "/api/v1/study-sessions/stop", method: "POST", as: StudySession.self)
    }

    // MARK: - Home Feed

    /// Get home feed (for polling)
    static func getHomeFeed() async throws -> HomeFeedResponse {
        try await perform(path: "/api/v1/home/feed", method: "GET", as: HomeFeedResponse.self)
    }
}
