import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var isSigningOut = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false
    @State private var showDeleteAccount = false

    private var currentUser: UserProfile? { appState.currentUser }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        UserIconView(
                            emoji: currentUser?.iconEmoji ?? "",
                            backgroundColor: currentUser?.iconBackgroundColor ?? "#FFD54F",
                            size: 72
                        )
                        Text(currentUser?.name ?? "")
                            .font(.headline)
                        Button("Edit Profile") {
                            showEditProfile = true
                        }
                        .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Account
                Section("Account") {
                    if let email = appState.userEmail {
                        HStack {
                            Text("Email")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(email)
                                .lineLimit(1)
                                .font(.subheadline)
                        }
                    }
                    
                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                }

                // Sign out and delete
                Section {
                    Button("Sign Out") {
                        showSignOutConfirmation = true
                    }
                    .foregroundStyle(.red)
                    .disabled(isSigningOut)

                    Button("Delete Account…") {
                        showDeleteAccount = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                if let profile = try? await APIClient.getMyProfile() {
                    appState.updateCurrentUser(profile)
                }
            }
        }
    }

    private func signOut() async {
        isSigningOut = true
        await appState.signOut()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
