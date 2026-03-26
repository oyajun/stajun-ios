//
//  ShareURL.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/26.
//

import Foundation
import SimpleKeychain

enum ShareURLError: Error {
    case noBaseURL
    case noUserID
}

func myAccountURL() throws -> URL {
    guard let baseURL = URL(string: ENV_BASEURL) else {
        throw ShareURLError.noBaseURL
    }

    let simpleKeychain = SimpleKeychain()
    let userId: String
    do {
        userId = try simpleKeychain.string(forKey: "userid")
    } catch {
        throw ShareURLError.noUserID
    }

    let url = baseURL
        .appendingPathComponent("mobile")
        .appendingPathComponent("user")
        .appendingPathComponent(userId)
    print(url)
    return url
}

enum DecodeError: Error {
    case unableToDecode
}

func decodeURL(urlString : String) throws -> String {
    guard let url = URL(string: urlString) else {
        throw DecodeError.unableToDecode
    }
    return url.lastPathComponent
}

