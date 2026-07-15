import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.authState {
        case .checking:
            // 起動時検証中
            ProgressView("読み込み中…")
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
