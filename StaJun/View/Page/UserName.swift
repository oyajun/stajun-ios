//
//  UserName.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct UserName: View {
    @State private var username: String = ""
    @FocusState private var userNameFieldIsFocused: Bool
    var body: some View {
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
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                }
                .foregroundStyle(Color(.systemBlue))
                .disabled(!username.isEmpty)
            }
        }
    }
}

#Preview {
    UserName()
}
