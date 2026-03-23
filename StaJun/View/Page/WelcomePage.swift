//
//  WelcomeView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/20.
//

import SwiftUI

struct WelcomePage: View {
    var body: some View {
        NavigationStack{
            VStack{
                Spacer()
                
                Text("Welcome to StaJun")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                Text("Share your studying status with your friends!")
                    .font(.subheadline)
                
                Spacer()
                
                NavigationLink {
                    LoginView()
                } label: {
                    Text("Sign Up / Log In")
                        .font(.title2)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    WelcomePage()
}
