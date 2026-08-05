import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo and title
                VStack(spacing: 8) {
                    Text("JunJun")
                        .font(.largeTitle.bold())
                    Text("What are you studying now?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        appState.authState = .anonymousOnboarding
                    } label: {
                        Text("Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.authState = .emailLogin
                    } label: {
                        Text("Log in if you already have an account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Link(destination: Config.termsOfServiceURL) {
                        Text("Terms of Service")
                    }
                    Link(destination: Config.privacyPolicyURL) {
                        Text("Privacy Policy")
                    }
                    Link(destination: Config.supportURL) {
                        Text("Support")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

                Spacer()
                    .frame(height: 16)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppState())
}
