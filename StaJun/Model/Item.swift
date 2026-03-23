//
//  Item.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
