//
//  ContentView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    //@Environment(\.modelContext) private var modelContext
    //@Query private var items: [Item]
    
    var body: some View {
        if (appState.status == .signIn) {
            NavigationStack{
                WelcomePage()
            }
        } else if (appState.status == .initialSetting) {
            NavigationStack{
                UserNameInitPage()
            }
        } else {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: Item.self, inMemory: true)
}

