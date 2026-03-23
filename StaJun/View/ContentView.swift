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

    @State private var studying : Bool = false
    @State private var searchText: String = ""
    
    var body: some View {
        if (appState.status == .signIn) {
            NavigationStack{
                WelcomePage()
            }
        } else if (appState.status == .initialSetting) {
            NavigationStack{
                UserName()
            }
        } else {
            ZStack{
                TabView {
                    Tab("Home", systemImage: "house.fill") {
                        HomeView(studying: $studying)
                    }
                    Tab("Welcome", systemImage: "gearshape.fill") {
                        NavigationStack{
                            WelcomePage()
                        }
                    }
                    Tab("Setting", systemImage: "gearshape.fill") {
                        NavigationStack{
                            IconChooser()
                        }
                    }
                    Tab("Username", systemImage: "gearshape.fill") {
                        NavigationStack{
                            UserName()
                        }
                    }
                    Tab(role: .search) {
                        OTPView(email: "example@example.com")
                    }
                }
            }
            .overlay(
                ZStack
                {
                    if studying {
                        RoundedRectangle(cornerRadius: 70)
                            .stroke(Color.green.opacity(1), lineWidth: 5)
                            .blur(radius: 10)
                            .ignoresSafeArea()
                        
                        Rectangle()
                            .stroke(Color.green.opacity(1), lineWidth: 5)
                            .blur(radius: 10)
                            .ignoresSafeArea()
                    }
                }

            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: Item.self, inMemory: true)
}

