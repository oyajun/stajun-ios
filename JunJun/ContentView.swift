import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.authState {
            case .checking:
                // Checking on startup
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .welcome:
                WelcomeView()

            case .emailLogin:
                EmailInputView()

            case .awaitingOTP(let email):
                OTPInputView(email: email)

            case .anonymousOnboarding:
                ProfileSetupView(isAnonymous: true)

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
