//
//  DeleteUserPage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/26.
//

import SwiftUI

struct DeleteUserPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showAlert: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showErrorAlert: Bool = false
    
    var body: some View {
        ZStack{
            NavigationStack {
                VStack(alignment: .leading){
                    Image(systemName: "trash")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 5)
                    Text("Delete Account")
                        .font(.largeTitle)
                    Text("Your account will be permanently deleted.")
                        
                    Spacer()
                    
                    Button {
                        showAlert = true
                    } label : {
                        Text("Delete Account")
                            .font(.title2)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color(.systemRed))
                    .buttonStyle(.glassProminent)
                    .padding(.bottom)
                    .alert("Do you want to delete your account?",
                           isPresented: $showAlert
                    ) {
                        Button("Delete", role: .destructive) {
                            Task{
                                isDeleting = true
                                if await deleteUser() {
                                    _ = await signOut()
                                    appState.status = .signIn
                                } else {
                                    showErrorAlert = true
                                    isDeleting = false
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                    .alert("Unable to delete your account. Please try again.",
                           isPresented: $showErrorAlert
                    ) {}
                    
                    Button {
                        dismiss()
                    } label : {
                        Text("Cancel")
                            .font(.title2)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                .padding()
            }
        
            if isDeleting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
}

#Preview {
    DeleteUserPage()
}
