//
//  UserName.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct UserNameInitPage: View {
    @State private var username: String = ""
    @FocusState private var userNameFieldIsFocused: Bool
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading){
                Image(systemName: "person.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
                
                Text("Set your User Name")
                    .font(.largeTitle)
                
                Text("This User Name displays on your profile.")
                    .padding(.bottom, 15)
                    
                TextField("User name", text: $username)
                    .focused($userNameFieldIsFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .autocorrectionDisabled(true)
                    .keyboardType(.default)
                    .textContentType(.nickname)
                    .textInputAutocapitalization(.never)
                    .onAppear { userNameFieldIsFocused = true }
                    .submitLabel(.next)
                    .onSubmit {
                        
                    }
                Spacer()
                
                NavigationLink {
                    IconInitPage(username: username)
                } label: {
                    Group{
                        Text("Next")
                    }
                    .font(.title2)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(username.isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    UserNameInitPage()
}
