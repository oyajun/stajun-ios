//
//  Auth.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/21.
//

// https://qiita.com/shungo_m/items/64564fd822a7558ac7b1

import Foundation
import SimpleKeychain

// return true:成功　false:エラー
func sendVerificationOtp(email: String) async -> Bool {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("api/auth/email-otp/send-verification-otp")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "email": email,
        "type": "sign-in"
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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


enum signinEmailOtpStatus: String {
    case none
    case newUser
    case existsUser
    case error
}

func signinEmailOtp(email: String, code: String) async -> signinEmailOtpStatus {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("api/auth/sign-in/email-otp")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "email": email,
        "otp": code
    ]

    var responseStruct : SignInResponse
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // async/await 通信
        let (data, response) = try await URLSession.shared.data(for: request)

        // ステータスコード確認
        guard let httpResponse = response as? HTTPURLResponse else {
            print("レスポンス不正")
            return signinEmailOtpStatus.error
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("ステータスコードエラー:", httpResponse.statusCode)
            if let text = String(data: data, encoding: .utf8) {
                print("レスポンス:", text)
            }
            return signinEmailOtpStatus.error
        }

        // デバッグ
        if let text = String(data: data, encoding: .utf8) {
            print("raw:", text)
        }

        // JSONパース
        responseStruct = try JSONDecoder().decode(SignInResponse.self, from: data)
        
        // アクセストークンをキーチェーンに保存
        let simpleKeychain = SimpleKeychain()
        try simpleKeychain.set(responseStruct.token, forKey: "better-auth-access-token")
        
    } catch {
        print("エラー:", error)
        return signinEmailOtpStatus.error
    }
    
    if responseStruct.user.name == "" {
        return signinEmailOtpStatus.newUser
    }else {
        return signinEmailOtpStatus.existsUser
    }
}

// return true:成功　false:エラー
func updateUser(name: String, iconEmoji: String, iconColor: String) async -> Bool {
    let baseUrl = URL(string: ENV_BASEURL)!
    let url = baseUrl.appendingPathComponent("api/auth/update-user")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "name": name,
        "image": "\(iconEmoji):\(iconColor)"
    ]

    do {
        let simpleKeychain = SimpleKeychain()
        guard let token = try? simpleKeychain.string(forKey: "better-auth-access-token") else {
            print("アクセストークンが取得できませんでした")
            return false
        }
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

// return true:成功　false:エラー
func signOut() async -> Bool {
    // キーチェーンからトークンを削除
    let simpleKeychain = SimpleKeychain()
    do {
        _ = try simpleKeychain.deleteItem(forKey: "better-auth-access-token")
    } catch {
        return true // 失敗しても無視
    }
    return true
    
//    // サーバーからトークンを削除
//    let baseUrl = URL(string: ENV_BASEURL)!
//    let url = baseUrl.appendingPathComponent("api/auth/sign-out")
//    
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    
//    do {
//        let simpleKeychain = SimpleKeychain()
//        guard let token = try? simpleKeychain.string(forKey: "better-auth-access-token") else {
//            print("アクセストークンが取得できませんでした")
//            return false
//        }
//        
//        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        
//        // async/await 通信
//        let (data, response) = try await URLSession.shared.data(for: request)
//
//        // ステータスコード確認
//        guard let httpResponse = response as? HTTPURLResponse else {
//            print("レスポンス不正")
//            return false
//        }
//
//        guard (200...299).contains(httpResponse.statusCode) else {
//            print("ステータスコードエラー:", httpResponse.statusCode)
//            if let text = String(data: data, encoding: .utf8) {
//                print("レスポンス:", text)
//            }
//            return false
//        }
//
//        // デバッグ
//        if let text = String(data: data, encoding: .utf8) {
//            print("raw:", text)
//        }
//
//        // JSONパース
//        let object = try JSONSerialization.jsonObject(with: data, options: [])
//        print("json:", object)
//
//    } catch {
//        print("エラー:", error)
//        return false
//    }
//    
//    return true
}
