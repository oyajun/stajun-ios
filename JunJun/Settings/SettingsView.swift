import MarketplaceKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var isSigningOut = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false
    @State private var showDeleteAccount = false
    @State private var showChangeEmail = false
    @State private var hasCopiedVersion = false
    @State private var installedStore: String = "-"

    private var currentUser: UserProfile? { appState.currentUser }
    private var appVersionString: String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return nil
        }
        return "\(version) (\(build))"
    }

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
                    if currentUser?.isAnonymous == true {
                        Text("By registering an email address, you can log in from other devices, and you can easily log back in if your current device is lost or damaged.")
                            .textCase(.none)
                    }
                }

                // About
                Section {
                    Link(destination: Config.websiteURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                            Text("Website (Out of App)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.blue)

                    Link(destination: Config.supportURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                            Text("Support (Out of App)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.blue)

                    Link(destination: Config.termsOfServiceURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                            Text("Terms of Service (Out of App)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.blue)
                    
                    Link(destination: Config.privacyPolicyURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                            Text("Privacy Policy (Out of App)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.blue)
                }
                
                // Developer
                Section {
                    Link(destination: URL(string: "https://oyajun.com")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                            Text("Jun Oyamada (oyajun) (Out of App)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.blue)
                } header: {
                    Text("Developer")
                }

                // Version & Store
                Section {
                    Button {
                        if let appVersionString {
                            UIPasteboard.general.string = appVersionString
                            hasCopiedVersion.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Version")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let appVersionString {
                                Text(verbatim: appVersionString)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: hasCopiedVersion)
                    .contextMenu {
                        if let appVersionString {
                            Button {
                                UIPasteboard.general.string = appVersionString
                                hasCopiedVersion.toggle()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }

                    HStack {
                        Text("Store")
                        Spacer()
                        Text(verbatim: installedStore)
                            .foregroundStyle(.secondary)
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
                await loadStoreInfo()
                if let profile = try? await APIClient.getMyProfile() {
                    appState.updateCurrentUser(profile)
                }
            }
        }
    }

    private func loadStoreInfo() async {
        do {
            let distributor = try await AppDistributor.current
            switch distributor {
            case .appStore:
                installedStore = "App Store"
            case .testFlight:
                installedStore = "TestFlight"
            case .marketplace(let name):
                installedStore = name.isEmpty ? "Alternative Marketplace" : name
            case .web:
                installedStore = "Web"
            case .other:
                installedStore = "Other"
            @unknown default:
                installedStore = "Unknown"
            }
        } catch {
            #if targetEnvironment(simulator)
            installedStore = "Simulator"
            #else
            installedStore = "Unknown"
            #endif
        }
    }

    private func signOut() async {
        isSigningOut = true
        await appState.signOut()
    }
}

extension AppDistributor: @retroactive @unchecked Sendable {}

#Preview {
    SettingsView()
        .environment(AppState())
}
