//
//  Activity.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import Foundation
import SimpleKeychain
import SwiftData

func changeActivity(nowStudying: Bool) async -> Bool {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("/api/v1/activity")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "nowStudying": nowStudying,
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
        let simpleKeychain = SimpleKeychain()
        guard let token = try? simpleKeychain.string(forKey: "better-auth-access-token") else {
            print("アクセストークンが取得できませんでした")
            return false
        }
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // async/await 通信
        let (data, response) = try await URLSession.shared.data(for: request)

        // ステータスコード確認
        guard let httpResponse = response as? HTTPURLResponse else {
            print("レスポンス不正")
            return false
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("ステータスコードエラー:", httpResponse.statusCode)
            if let text = String(data: data, encoding: .utf8) {
                print("レスポンス:", text)
            }
            return false
        }

        // デバッグ
        if let text = String(data: data, encoding: .utf8) {
            print("raw:", text)
        }
    } catch {
        print("エラー:", error)
        return false
    }
    return true
}


func setFolloweesActivity(context: ModelContext) async {
    var followees: [ActivityResponseUser] = []
    do {
        followees = try await getFolloweesActivityServer()
    } catch let error {
//        switch error {
//        case APIError.clientError:
//        case APIError.decodingError:
//        case APIError.invalidResponse:
//        case APIError.networkError:
//        case APIError.serverError:
//        default:
//        }
        print("Failed to fetch followees activity:", error)
        return
    }

    do {
        let fetchDescriptor = FetchDescriptor<User>()
        let fetchedItems = try context.fetch(fetchDescriptor)
        for user in fetchedItems {
            context.delete(user)
        }
        try context.save()
    } catch {
        print("Failed to clear existing users:", error)
    }

    for followee in followees {
        print("a")
        let user = User(activityResponseUser: followee)
        context.insert(user)
    }
    try? context.save()
}

private func getFolloweesActivityServer() async throws -> [ActivityResponseUser] {
    let url = URL(string: ENV_BASEURL)!
        .appendingPathComponent("/api/v1/user/followee")

    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let simpleKeychain = SimpleKeychain()
    guard let token = try? simpleKeychain.string(forKey: "better-auth-access-token") else {
        throw APIError.unauthorized
    }

    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            guard !data.isEmpty else {
                print("データが空")
                return []
            }
            do {
                return try JSONDecoder().decode([ActivityResponseUser].self, from: data)
            } catch {
                throw APIError.decodingError
            }

        case 401:
            throw APIError.unauthorized

        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)

        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)

        default:
            throw APIError.invalidResponse
        }

    } catch let error as URLError {
        throw APIError.networkError(error)
    }
}

