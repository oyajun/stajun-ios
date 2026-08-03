import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
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
}

#Preview {
    ContentView()
        .environment(AppState())
}
