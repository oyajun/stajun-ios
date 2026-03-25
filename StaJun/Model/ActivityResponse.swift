//
//  ActivityResponse.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/25.
//

import Foundation

struct ActivityResponseUser: Codable, Identifiable {
    let id: String
    let name: String
    let image: String?
    let activity : ActivityResponse
}

struct ActivityResponse: Codable {
    let studyingNow: Bool
    let updatedAt: String
}
