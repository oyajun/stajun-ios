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
        if (isSignedIn()){
            self.status = .home
        } else {
            self.status = .signIn
        }
    }
}
