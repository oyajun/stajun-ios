//
//  HomeView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import SwiftUI

struct HomeView: View {
    @State private var studying : Bool = false
    @State private var searchText: String = ""
    
    var body: some View {
        ZStack{
            TabView {
                Tab("Home", systemImage: "house.fill") {
                    HomePage(studying: $studying)
                }
                Tab("Welcome", systemImage: "gearshape.fill") {
                    NavigationStack{
                        WelcomePage()
                    }
                }
                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsPage()
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

#Preview {
    HomeView()
}
