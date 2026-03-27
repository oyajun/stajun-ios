//
//  SettingsPage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject var appState: AppState
    @State private var showSignOutDialog: Bool = false
    @State private var isSignOuting: Bool = false
    @State private var showSignOutError: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile")) {
                    NavigationLink {} label: {
                        Label("User Name", systemImage: "pencil")
                    }
                    NavigationLink {} label: {
                        Label("Icon", systemImage: "face.smiling")
                    }
                }
                
                Section(){
                    NavigationLink {About()} label: {
                        Label("About StaJun", systemImage: "info.circle")
                    }
                }
                
                Section (){
                    Button {
                        showSignOutDialog = true
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color.red)
                    }
                    .alert("Log out", isPresented: $showSignOutDialog) {
                        Button("Cancel", role: .cancel) {
                            showSignOutDialog = false
                        }.disabled(isSignOuting)
                        Button("Log out", role: .destructive)
                        {
                            Task{
                                if (await signOut()){
                                    appState.status = .signIn
                                } else {
                                    showSignOutDialog = false
                                    showSignOutError = true
                                }
                            }
                        }.disabled(isSignOuting)
                    } message: {
                        Text("Are you sure you want to log out?")
                    }
                    .alert("Failed to log out", isPresented: $showSignOutError) {
                    }
                }
                
                Section(){
                    NavigationLink() {
                        DeleteUserPage()
                    } label: {
                        Label("Delete your account", systemImage: "trash")
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsPage()
}
