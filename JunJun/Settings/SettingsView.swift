import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var isSigningOut = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false
    @State private var showDeleteAccount = false
    @State private var showChangeEmail = false

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
                Section {
                    HStack {
                        Text("Email")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showChangeEmail = true
                        } label: {
                            if let email = appState.userEmail {
                                Text(email)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Register Email")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    NavigationLink("Push Notifications") {
                        PushNotificationSettingsView()
                    }

                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                        if currentUser?.isAnonymous == true {
                            Text("By registering an email address, you can log in from other devices, and you can easily log back in if your current device is lost or damaged.")
                                .textCase(.none)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Sign out and delete
                Section {
                    if currentUser?.isAnonymous == false {
                        Button("Sign Out") {
                            showSignOutConfirmation = true
                        }
                        .foregroundStyle(.red)
                        .disabled(isSigningOut)
                    }

                    Button("Delete Account…") {
                        showDeleteAccount = true
                    }
                    .foregroundStyle(.red)
                }
                
                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text(verbatim: "\(version) (\(build))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: Config.supportURL) {
                        HStack {
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Link(destination: Config.termsOfServiceURL) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: Config.privacyPolicyURL) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("About")
                }
                
                // Developer
                Section {
                    Link(destination: URL(string: "https://oyajun.com")!) {
                        HStack {
                            Text(verbatim: "小山田純(oyajun)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Developer")
                }
                
                Text(verbatim: "from Japan 🇯🇵")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showChangeEmail) {
                ChangeEmailView()
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
