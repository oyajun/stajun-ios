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
                // Profile
                Section {
                    HStack(spacing: 12) {
                        Spacer()
                        VStack(spacing: 8) {
                            UserIconView(
                                emoji: currentUser?.iconEmoji ?? "",
                                backgroundColor: currentUser?.iconBackgroundColor ?? "#FFD54F",
                                size: 72
                            )
                            Text(currentUser?.username ?? "")
                                .font(.headline)
                        }
                        Spacer()
                        VStack {
                            Button(action: { showEditProfile = true }) {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }

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
