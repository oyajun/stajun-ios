import SwiftUI

@Observable
class AuthRouter {
    var path: [AuthRoute] = []
}

enum AuthRoute: Hashable {
    case loginEmail
    case registerEmail
    case awaitingOTP(email: String, mode: AuthFlowMode)
    case anonymousOnboarding
}

struct AuthCoordinatorView: View {
    @State private var router = AuthRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            WelcomeView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .loginEmail:
                        EmailInputView(mode: .login)
                    case .registerEmail:
                        EmailInputView(mode: .registerEmail)
                    case .awaitingOTP(let email, let mode):
                        OTPInputView(email: email, mode: mode)
                    case .anonymousOnboarding:
                        ProfileSetupView(isAnonymous: true)
                    }
                }
        }
        .environment(router)
    }
}

private struct DeepLinkTargetUser: Identifiable {
    let id: String
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @State private var showUnauthenticatedDeepLinkAlert = false

    var body: some View {
        Group {
            switch appState.authState {
            case .checking:
                // Checking on startup
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .unauthenticated:
                AuthCoordinatorView()

            case .authenticated:
                MainTabView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.authState == .authenticated {
                appState.requestPushPermissionIfAppropriate()
            }
        }
        .onOpenURL { url in
            if appState.authState == .unauthenticated {
                showUnauthenticatedDeepLinkAlert = true
            } else {
                appState.handleOpenURL(url)
            }
        }
        .sheet(item: Binding(
            get: { appState.deepLinkedUserId.map { DeepLinkTargetUser(id: $0) } },
            set: { if $0 == nil { appState.deepLinkedUserId = nil } }
        )) { target in
            NavigationStack {
                UserProfileView(userId: target.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                appState.deepLinkedUserId = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .alert("Please create an account or log in before opening this link again.", isPresented: $showUnauthenticatedDeepLinkAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Update Required", isPresented: Binding(
            get: { appState.requiresUpdate },
            set: { _ in }
        )) {
            Button("Update") {
                if let url = Config.appStoreURL {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("This app version has expired.\nPlease update to the latest version.")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
