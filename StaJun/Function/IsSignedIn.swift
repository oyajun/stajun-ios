//
//  IsSignedIn.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/23.
//

import Foundation
import SimpleKeychain

func isSignedIn() -> Bool {
    let keychain = SimpleKeychain()
    return (try? keychain.hasItem(forKey: "better-auth-access-token")) ?? false
}
