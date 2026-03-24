//
//  UserSignIn.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/23.
//


struct SignInResponse: Codable {
    let token: String
    let user: SignInResponseUser
}


struct SignInResponseUser: Codable {
    let id: String
    let name: String
    let email: String
    let emailVerified: Bool
    let image: String?
    let createdAt: String
    let updatedAt: String
}
