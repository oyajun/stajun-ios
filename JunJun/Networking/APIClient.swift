import Foundation

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case unauthorized
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
            return String(localized: "Please log in to continue.")
        case .sessionNotFresh:
            return String(localized: "Your session has expired. Please log in again.")
        case .forbidden(let code, _):
            switch code {
            case "USER_BLOCKED":
                return String(localized: "This user is blocked.")
            default:
                return String(localized: "You do not have permission to perform this action.")
            }
        case .notFound:
            return String(localized: "The requested content could not be found.")
        case .conflict(let code, _):
            switch code {
            case "EMAIL_ALREADY_IN_USE":
                return String(localized: "This email address is already in use.")
            case "USER_ALREADY_EXISTS":
                return String(localized: "This user already exists.")
            default:
                return String(localized: "A conflict occurred. Please try again.")
            }
        case .badRequest(let code, _):
            switch code {
            case "INVALID_OTP", "OTP_EXPIRED":
                return String(localized: "The verification code is invalid or has expired.")
            case "INVALID_EMAIL":
                return String(localized: "Please enter a valid email address.")
            case "INVALID_NAME":
                return String(localized: "Please enter a valid name.")
            case "INVALID_MINUTES":
                return String(localized: "Please enter a valid study time.")
            default:
                return String(localized: "Invalid request. Please check your input.")
            }
        case .serverError:
            return String(localized: "A server error occurred. Please try again later.")
        case .networkError(let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    return String(localized: "You are offline. Please check your internet connection.")
                case NSURLErrorTimedOut:
                    return String(localized: "The connection timed out. Please try again.")
                case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorBadServerResponse:
                    return String(localized: "Cannot connect to the server. The server may be temporarily down or unreachable.")
                default:
                    return String(localized: "Unable to connect. Please check your internet connection and try again.")
                }
            }
            return String(localized: "Unable to connect. Please check your internet connection and try again.")
        case .decodingError:
            return String(localized: "Failed to process data. Please try again.")
        case .unknown:
            return String(localized: "An unexpected error occurred. Please try again.")
        }
    }
}

extension Error {
    /// Returns true if the error represents a task or network request cancellation.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let apiError = self as? APIError, case .networkError(let underlying) = apiError {
            return underlying.isCancellation
        }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
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

    private static let userAgent: String = {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "JunJun"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = os.patchVersion == 0
            ? "\(os.majorVersion).\(os.minorVersion)"
            : "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        return "\(appName)/\(version) (\(build); iOS \(osVersion))"
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
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

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
            var code = "UNKNOWN"
            var message = "An error occurred."
            
            // Try app standard format first
            if let parsed = try? decoder.decode(APIErrorResponse.self, from: data) {
                code = parsed.error.code
                message = parsed.error.message
            } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try better-auth default format
                if let msg = dict["message"] as? String {
                    message = msg
                }
                if let c = dict["code"] as? String {
                    code = c
                } else if let err = dict["error"] as? String {
                    code = err
                }
            }
            switch http.statusCode {
            case 401: throw APIError.unauthorized
            case 403:
                switch code {
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
    static func sendOTP(email: String, type: String = "sign-in") async throws {
        try await perform(path: "/api/auth/email-otp/send-verification-otp", method: "POST", body: SendOTPRequest(email: email, type: type), as: EmptyResponse.self)
    }

    /// Sign in with OTP (set-auth-token auto-saved to Keychain)
    static func signIn(email: String, otp: String) async throws {
        try await perform(path: "/api/auth/sign-in/email-otp", method: "POST", body: VerifyOTPRequest(email: email, otp: otp), as: EmptyResponse.self)
    }

    /// Sign in anonymously (set-auth-token auto-saved to Keychain)
    static func signInAnonymous() async throws {
        try await perform(path: "/api/auth/sign-in/anonymous", method: "POST", body: EmptyRequest(), as: EmptyResponse.self)
    }

    /// Request Email Change (sends OTP to new email)
    static func requestEmailChange(newEmail: String) async throws {
        try await perform(path: "/api/auth/email-otp/request-email-change", method: "POST", body: RequestEmailChangeRequest(newEmail: newEmail), as: EmptyResponse.self)
    }

    /// Change Email with OTP
    static func changeEmail(newEmail: String, otp: String) async throws {
        try await perform(path: "/api/auth/email-otp/change-email", method: "POST", body: ChangeEmailRequest(newEmail: newEmail, otp: otp), as: EmptyResponse.self)
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

    /// Update profile (partial update)
    static func updateProfile(name: String? = nil, iconEmoji: String? = nil, iconBackgroundColor: String? = nil) async throws -> UserProfile {
        let body = UpdateProfileRequest(name: name, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        return try await perform(path: "/api/v1/users/me", method: "PATCH", body: body, as: UserProfile.self)
    }

    /// Delete account (fresh session required)
    static func deleteAccount() async throws {
        try await perform(path: "/api/v1/users/me", method: "DELETE", as: EmptyResponse.self)
    }

    /// Delete anonymous account
    static func deleteAnonymousAccount() async throws {
        try await perform(path: "/api/auth/delete-anonymous-user", method: "POST", body: EmptyRequest(), as: EmptyResponse.self)
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

    /// Get recommended users (up to 10 users)
    static func getRecommendedUsers() async throws -> RecommendedUsersResponse {
        try await perform(path: "/api/v1/users/recommended", method: "GET", as: RecommendedUsersResponse.self)
    }


    /// Follow a user
    static func follow(userId: String) async throws -> FollowActionResponse {
        try await perform(path: "/api/v1/follow/\(userId)", method: "PUT", as: FollowActionResponse.self)
    }

    /// Mute study start notifications from a followed user
    static func muteFollow(userId: String) async throws -> MuteActionResponse {
        try await perform(path: "/api/v1/follow/\(userId)/mute", method: "PUT", as: MuteActionResponse.self)
    }

    /// Unmute study start notifications from a followed user
    static func unmuteFollow(userId: String) async throws -> MuteActionResponse {
        try await perform(path: "/api/v1/follow/\(userId)/mute", method: "DELETE", as: MuteActionResponse.self)
    }

    /// Update follow notification mute setting
    static func updateFollowMute(userId: String, isMuted: Bool) async throws -> MuteActionResponse {
        if isMuted {
            return try await muteFollow(userId: userId)
        } else {
            return try await unmuteFollow(userId: userId)
        }
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

    // MARK: - Block

    /// Block a user
    static func blockUser(userId: String) async throws {
        try await perform(path: "/api/v1/block/\(userId)", method: "PUT", as: EmptyResponse.self)
    }

    /// Unblock a user
    static func unblockUser(userId: String) async throws {
        try await perform(path: "/api/v1/block/\(userId)", method: "DELETE", as: EmptyResponse.self)
    }

    /// Get list of blocked users
    static func getBlockedUsers(limit: Int = 20, offset: Int = 0) async throws -> BlockedUsersResponse {
        try await perform(path: "/api/v1/blocks?limit=\(limit)&offset=\(offset)", method: "GET", as: BlockedUsersResponse.self)
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

    // MARK: - Polling

    /// Poll combined status (unread notifications count, following users with study status, and own study session)
    static func poll() async throws -> PollingResponse {
        try await perform(path: "/api/v1/polling", method: "GET", as: PollingResponse.self)
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

    /// Report a post.
    static func reportPost(id: String) async throws {
        try await perform(path: "/api/v1/posts/\(id)/report", method: "POST", as: EmptyResponse.self)
    }

    /// Like a post.
    static func likePost(id: String) async throws -> LikePostResponse {
        try await perform(path: "/api/v1/posts/\(id)/like", method: "POST", as: LikePostResponse.self)
    }

    /// Unlike a post.
    static func unlikePost(id: String) async throws -> LikePostResponse {
        try await perform(path: "/api/v1/posts/\(id)/like", method: "DELETE", as: LikePostResponse.self)
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

    // MARK: - Push Notifications

    /// Register APNs device token with the server
    static func registerAPNsToken(token: String) async throws {
        struct RegisterAPNsTokenRequest: Encodable {
            let token: String
        }
        try await perform(path: "/api/v1/apns-token", method: "POST", body: RegisterAPNsTokenRequest(token: token), as: EmptyResponse.self)
    }

    /// Get current push notification settings
    static func getPushNotificationSettings() async throws -> PushNotificationSettings {
        try await perform(path: "/api/v1/settings/push-notifications", method: "GET", as: PushNotificationSettings.self)
    }

    /// Update push notification settings
    static func updatePushNotificationSettings(
        enabled: Bool? = nil,
        follow: Bool? = nil,
        studyStart: Bool? = nil
    ) async throws -> PushNotificationSettings {
        let body = UpdatePushNotificationSettingsRequest(
            enabled: enabled,
            follow: follow,
            studyStart: studyStart
        )
        return try await perform(path: "/api/v1/settings/push-notifications", method: "PUT", body: body, as: PushNotificationSettings.self)
    }

    // MARK: - Notifications

    /// Get list of notifications (cursor-paginated)
    static func getNotifications(cursor: String? = nil, limit: Int = 20) async throws -> NotificationsResponse {
        var query = ["limit=\(limit)"]
        if let cursor, let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query.append("cursor=\(encoded)")
        }
        let path = "/api/v1/notifications?" + query.joined(separator: "&")
        return try await perform(path: path, method: "GET", as: NotificationsResponse.self)
    }

    /// Mark all unread notifications as read
    static func markAllNotificationsAsRead() async throws {
        try await perform(path: "/api/v1/notifications/read-all", method: "POST", as: EmptyResponse.self)
    }

    /// Mark a specific notification as read
    static func markNotificationAsRead(id: String) async throws {
        try await perform(path: "/api/v1/notifications/\(id)/read", method: "PATCH", as: EmptyResponse.self)
    }

    /// Get unread notifications count
    static func getUnreadNotificationCount() async throws -> Int {
        let res = try await perform(path: "/api/v1/notifications/unread-count", method: "GET", as: UnreadNotificationCountResponse.self)
        return res.unreadCount
    }

    // MARK: - Subscriptions (JunJun Pro)

    /// Sync Pro status with server
    static func syncProStatus(isPro: Bool, proExpiresAt: Date? = nil) async throws -> SyncProStatusResponse {
        let expiresAtString: String?
        if let proExpiresAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAtString = formatter.string(from: proExpiresAt)
        } else {
            expiresAtString = nil
        }
        let body = SyncProStatusRequest(isPro: isPro, proExpiresAt: expiresAtString)
        return try await perform(path: "/api/v1/users/me/pro-status", method: "POST", body: body, as: SyncProStatusResponse.self)
    }

    /// Fetch Pro status from server
    static func getProStatus() async throws -> SyncProStatusResponse {
        try await perform(path: "/api/v1/users/me/pro-status", method: "GET", as: SyncProStatusResponse.self)
    }
}

