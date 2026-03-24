//
//  User.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import Foundation
import SwiftData

@Model
class User {
    var id: String
    var name: String
    var iconColor: String
    var iconEmoji: String
    //var activity: Activity?
    
    init(signInResponseUser : SignInResponseUser) {
        self.id = signInResponseUser.id
        self.name = signInResponseUser.name

        // デフォルト値
        self.iconColor = "#0000FF"
        self.iconEmoji = "❓"

        guard let iconString = signInResponseUser.image else { return }

        let parts = iconString.split(separator: ":")

        guard parts.count >= 2 else { return }

        let emoji = String(parts[0])
        let colorCode = String(parts[1])

        if emoji.count == 1 {
            self.iconEmoji = emoji
        }
        
        if colorCode.count == 7 {
            self.iconColor = colorCode
        }
    }
}

//@Model
//class Activity {
//
//}
