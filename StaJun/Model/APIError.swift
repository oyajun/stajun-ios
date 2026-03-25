//
//  APIError.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/25.
//

import Foundation

enum APIError: Error {
    case unauthorized // 
    case invalidResponse
    case serverError(Int)
    case clientError(Int)
    case decodingError
    case networkError(URLError)
}
