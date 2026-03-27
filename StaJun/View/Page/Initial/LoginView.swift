//
//  UserName.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @FocusState private var emailFieldIsFocused: Bool
    @State private var isSending: Bool = false
    @State private var isSuccess: Bool = false
    @State private var showErrorAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading){
                Image(systemName: "at")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
                
                Text("Enter your Email Address")
                    .font(.largeTitle)
                
                Text("The email address is used to send a login code.")
                    .padding(.bottom, 15)
                
                TextField("Email address", text: $email)
                    .focused($emailFieldIsFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .onAppear { emailFieldIsFocused = true }
                    .submitLabel(.next)
                    .onSubmit {
                        
                    }
                Spacer()
                
                Button {
                    Task{
                        isSending = true
                        isSuccess = await sendVerificationOtp(email: email)
                        isSending = false
                        if (!isSuccess){
                            showErrorAlert = true
                        }
                    }
                } label : {
                    Group{
                        if !isSending {
                            Text("Next")
                        } else {
                            ProgressView()
                        }
                    }
                    .font(.title2)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(!email.isEmail || isSending)
            }
            .padding()
        }
        .alert("Some error occurred", isPresented: $showErrorAlert) {
            Button("Close") {
                showErrorAlert = false
            }
        }
        .navigationDestination(
            isPresented: $isSuccess,
        ){
            OTPView(email: email)
        }
    }
    
}

extension String {
    var isEmail: Bool {
        let regex =
        #"^[\p{L}0-9._%+\-]+@[\p{L}0-9.\-]+\.[\p{L}]{2,}$"#
        
        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: self)
    }
}

#Preview {
    LoginView()
}

