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
    var id: String; @Attribute(.unique)
    var name: String
    var iconColor: String
    var iconEmoji: String
    var activityNowStudying: Bool
    var activityUpdatedAt: String
    
    init(activityResponseUser : ActivityResponseUser) {
        self.id = activityResponseUser.id
        self.name = activityResponseUser.name
        (self.iconColor, self.iconEmoji)
            = Image2ColorEmoji(image: activityResponseUser.image)
        self.activityNowStudying =  activityResponseUser.activity.studyingNow
        self.activityUpdatedAt = activityResponseUser.activity.updatedAt
    }
}
