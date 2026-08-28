import SwiftUI
import UIKit
import StoreKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var isSigningOut = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false
    @State private var showDeleteAccount = false
    @State private var showChangeEmail = false
    @State private var showPaywall = false
    @State private var showManageSubscriptionsSheet = false
    @State private var hasCopiedVersion = false
    @State private var installedStore: String? = StoreDetector.defaultStoreName

    private var currentUser: UserProfile? { appState.currentUser }
    private var subscriptionManager = SubscriptionManager.shared
    private var isPro: Bool {
        appState.isPro || subscriptionManager.isPro || currentUser?.isPro == true
    }
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
                                isStudying: appState.isStudying,
                                isPro: isPro
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

                        if isPro {
                            Button {
                                showPaywall = true
                            } label: {
                                ProBadge()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.bottom, 8)
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

                // Plan Section
                Section {
                    HStack {
                        Text("Current Plan")
                            .foregroundStyle(.primary)

                        Spacer()

                        if isPro {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                                Text("JunJun Pro")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Text("Free Plan")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // JunJun Pro Details Card (always visible)
                    Button {
                        showPaywall = true
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.orange, .yellow, .pink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    Text("JunJun Pro")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                Text(SubscriptionManager.shared.localizedPriceString + " / " + String(localized: "month"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text("No ads & Rainbow icon")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text("View Details (In-App Purchase)")
                                    .font(.system(size: 17))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.blue)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Manage Subscription & Refund buttons (shown when subscribed)
                    if isPro {
                        Button {
                            showManageSubscriptionsSheet = true
                        } label: {
                            HStack {
                                Text("Manage Subscription")
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("App Store")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Link(destination: Config.appleRefundURL) {
                            HStack {
                                Text("Request Refund")
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("Apple")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                            Text("Jun Oyamada (Out of App)")
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

                    if let installedStore {
                        HStack {
                            Text("Store")
                            Spacer()
                            Text(verbatim: installedStore)
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptionsSheet)
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                if StoreDetector.isSupported {
                    if let store = await StoreDetector.fetchStoreName() {
                        installedStore = store
                    }
                }
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
