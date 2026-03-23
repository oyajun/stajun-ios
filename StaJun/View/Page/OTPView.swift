//
//  OTPView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/20.
//

import SwiftUI

struct OTPView: View {
    let email: String
    @State private var logincode: String = ""
    @FocusState private var logincodeFieldIsFocused: Bool
    @State private var isSending: Bool = false
    @State private var loginStatus: signinEmailOtpStatus
                        = signinEmailOtpStatus.none
    @State private var showErrorAlert: Bool = false
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading){
                Image(systemName: "number")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
                Text("Enter the Login Code")
                    .font(.largeTitle)
                
                Text("A login code has been sent to\n\"\(email)\"\nCheck your inbox and spam folder")
                    .padding(.bottom, 15)
                
                TextField("Login Code", text: $logincode)
                    .focused($logincodeFieldIsFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .autocorrectionDisabled(true)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.never)
                    .onAppear { logincodeFieldIsFocused = true }
                    .submitLabel(.next)
                
                //                Button("Resend Login Code") {
                //                }
                //                .padding(12)
                
                
                
                Spacer()
                
                Button {
                    Task{
                        isSending = true
                        loginStatus = await signinEmailOtp(email: email, code: logincode)
                        isSending = false
                        switch loginStatus {
                            case .newUser:
                                appState.status = .initialSetting
                            case .existsUser:
                                appState.status = .home
                            case .error:
                                showErrorAlert = true
                            case .none:
                                break
                        }
                    }
                } label : {
                    Group{
                        if !isSending {
                            Text("Send")
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
                .disabled( logincode.isEmpty || isSending)
            }
            .padding()
        }
        .alert("Some error occurred", isPresented: $showErrorAlert) {
            Button("Close") {
                showErrorAlert = false
                loginStatus = .none
            }
        }
    }
}

#Preview {
    OTPView(email: "example@example.com")
}

