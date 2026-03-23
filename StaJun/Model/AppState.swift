//
//  AppState.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/23.
//

import SwiftUI
import Combine

enum AppStateAction {
    case signIn
    case initialSetting
    case home
}

class AppState: ObservableObject {
    @Published var status: AppStateAction
    
    init() {
        // TODO: ログインしているか判定する
        self.status = .signIn
    }
}
