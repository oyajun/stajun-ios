import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.authState {
        case .checking:
            // Checking on startup
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .unauthenticated:
            EmailInputView()

        case .awaitingOTP(let email):
            OTPInputView(email: email)

        case .onboarding:
            ProfileSetupView()

        case .authenticated:
            MainTabView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
