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

struct ContentView: View {
    @Environment(AppState.self) private var appState

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
