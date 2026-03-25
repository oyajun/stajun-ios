//
//  Image2ColorEmoji.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/25.
//

import Foundation

func Image2ColorEmoji(image: String?) -> (IconColor: String, IconEmoji: String) {
    // デフォルト値
    var iconColor = "#0000FF"
    var iconEmoji = "❓"
    if image == nil { return (iconColor, iconEmoji) }

    let parts = image!.split(separator: ":")

    guard parts.count >= 2 else { return (iconColor, iconEmoji) }

    let emoji = String(parts[0])
    let colorCode = String(parts[1])

    if emoji.count == 1 {
        iconEmoji = emoji
    }
    
    if colorCode.count == 7 {
        iconColor = colorCode
    }
    return (iconColor, iconEmoji)
}
