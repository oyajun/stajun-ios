//
//  Follow.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import Foundation
import SimpleKeychain

func follow(userId: String) async -> Bool  {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("api/v1/follow/\(userId)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    do {
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

func unfollow(userId: String) async -> Bool {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("api/v1/follow/\(userId)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"

    do {
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

        // JSONパース
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        print("json:", object)

    } catch {
        print("エラー:", error)
        return false
    }
    return true
}
