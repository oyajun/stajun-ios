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
            return "ログインが必要です。"
        case .onboardingRequired:
            return "プロフィール設定が必要です。"
        case .sessionNotFresh:
            return "セッションが古くなっています。再認証してください。"
        case .forbidden(_, let msg):
            return msg
        case .notFound:
            return "見つかりませんでした。"
        case .conflict(_, let msg):
            return msg
        case .badRequest(_, let msg):
            return msg
        case .serverError(_, let msg):
            return msg
        case .networkError(let e):
            return e.localizedDescription
        case .decodingError(let e):
            return "データの解析に失敗しました: \(e.localizedDescription)"
        case .unknown:
            return "不明なエラーが発生しました。"
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
        let url = Config.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // better-auth CSRF対策として Origin ヘッダを設定（末尾のスラッシュは除去）
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

    /// レスポンスボディを T にデコードして返す。4xx/5xx は APIError を throw。
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

        // Bearer トークンをヘッダから自動保存
        if let token = http.value(forHTTPHeaderField: "set-auth-token"), !token.isEmpty {
            KeychainHelper.token = token
        }

        if http.statusCode >= 400 {
            let parsed = try? decoder.decode(APIErrorResponse.self, from: data)
            let code = parsed?.error.code ?? "UNKNOWN"
            let message = parsed?.error.message ?? "エラーが発生しました。"
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

    /// OTP メールを送信する
    static func sendOTP(email: String) async throws {
        try await perform(path: "/api/auth/email-otp/send-verification-otp", method: "POST", body: SendOTPRequest(email: email), as: EmptyResponse.self)
    }

    /// OTP でサインイン（set-auth-token を Keychain に自動保存）
    static func signIn(email: String, otp: String) async throws {
        try await perform(path: "/api/auth/sign-in/email-otp", method: "POST", body: VerifyOTPRequest(email: email, otp: otp), as: EmptyResponse.self)
    }

    /// サインアウト（Keychain のトークンは呼び出し側で削除すること）
    static func signOut() async throws {
        try await perform(path: "/api/auth/sign-out", method: "POST", as: EmptyResponse.self)
    }

    // MARK: - Profile

    /// 自分のプロフィール取得
    static func getMyProfile() async throws -> UserProfile {
        try await perform(path: "/api/v1/users/me", method: "GET", as: UserProfile.self)
    }

    /// 初回プロフィール登録（オンボーディング）
    static func createProfile(username: String, iconEmoji: String, iconBackgroundColor: String) async throws -> UserProfile {
        let body = CreateProfileRequest(username: username, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        return try await perform(path: "/api/v1/users/me", method: "POST", body: body, as: UserProfile.self)
    }

    /// プロフィール更新（部分更新）
    static func updateProfile(username: String? = nil, iconEmoji: String? = nil, iconBackgroundColor: String? = nil) async throws -> UserProfile {
        let body = UpdateProfileRequest(username: username, iconEmoji: iconEmoji, iconBackgroundColor: iconBackgroundColor)
        return try await perform(path: "/api/v1/users/me", method: "PATCH", body: body, as: UserProfile.self)
    }

    /// アカウント削除（フレッシュなセッション必須）
    static func deleteAccount() async throws {
        try await perform(path: "/api/v1/users/me", method: "DELETE", as: EmptyResponse.self)
    }

    // MARK: - Users

    /// 他ユーザーのプロフィール取得（id 指定）
    static func getUser(id: String) async throws -> UserWithStudyStatus {
        try await perform(path: "/api/v1/users/\(id)", method: "GET", as: UserWithStudyStatus.self)
    }

    /// ユーザー検索
    static func searchUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> SearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await perform(path: "/api/v1/users/search?q=\(encoded)&limit=\(limit)&offset=\(offset)", method: "GET", as: SearchResponse.self)
    }

    // MARK: - Follow

    /// フォローする
    static func follow(userId: String) async throws -> FollowActionResponse {
        try await perform(path: "/api/v1/users/\(userId)/follow", method: "POST", as: FollowActionResponse.self)
    }

    /// フォロー解除
    static func unfollow(userId: String) async throws {
        try await perform(path: "/api/v1/users/\(userId)/follow", method: "DELETE", as: EmptyResponse.self)
    }

    /// フォロー中一覧
    static func getFollowing() async throws -> FollowingResponse {
        try await perform(path: "/api/v1/me/following", method: "GET", as: FollowingResponse.self)
    }

    // MARK: - Study Sessions

    /// 自分の現在の学習状態取得
    static func getMyStudyStatus() async throws -> MyStudyStatus {
        try await perform(path: "/api/v1/study-sessions/me", method: "GET", as: MyStudyStatus.self)
    }

    /// 勉強開始
    static func startStudy() async throws -> StudySession {
        try await perform(path: "/api/v1/study-sessions/start", method: "POST", as: StudySession.self)
    }

    /// 勉強終了
    static func stopStudy() async throws -> StudySession {
        try await perform(path: "/api/v1/study-sessions/stop", method: "POST", as: StudySession.self)
    }

    // MARK: - Home Feed

    /// ホームフィード取得（ポーリング用）
    static func getHomeFeed() async throws -> HomeFeedResponse {
        try await perform(path: "/api/v1/home/feed", method: "GET", as: HomeFeedResponse.self)
    }
}
