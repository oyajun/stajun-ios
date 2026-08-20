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
                        Button {
                            showEditProfile = true
                        } label: {
                            UserIconView(
                                emoji: currentUser?.iconEmoji ?? "",
                                backgroundColor: currentUser?.iconBackgroundColor ?? "#FFD54F",
                                size: 80,
                                isStudying: appState.isStudying
                            )
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                            .overlay(alignment: .center) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                                    )
                                    .offset(x: 28, y: 28)
                            }
                        }
                        .buttonStyle(.plain)

                        if let name = currentUser?.name, !name.isEmpty {
                            Text(name)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 0)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Profile
                Section {
                    if let userId = currentUser?.id {
                        NavigationLink("View Profile Page") {
                            UserProfileView(userId: userId)
                        }
                    }

                    Button {
                        showEditProfile = true
                    } label: {
                        HStack {
                            Text("Edit Profile")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let userId = currentUser?.id,
                       let shareURL = URL(string: "https://junjun.oyajun.com/u/\(String(userId.prefix(10)))") {
                        ShareLink(item: shareURL) {
                            HStack {
                                Text("Share Profile")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Account
                Section {
                    Button {
                        showChangeEmail = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Email")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let email = appState.userEmail {
                                Text(email)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Register Email")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
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
