import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthRouter.self) private var authRouter: AuthRouter?

    private var agreementAttributedString: AttributedString {
        let termsURL = Config.termsOfServiceURL.absoluteString
        let privacyURL = Config.privacyPolicyURL.absoluteString
        let format = String(
            localized: "By continuing, you agree to our [Terms of Service](%1$@) and [Privacy Policy](%2$@)."
        )
        let formatted = String(format: format, termsURL, privacyURL)
        if let attributed = try? AttributedString(markdown: formatted, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(formatted)
    }

    var body: some View {
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
                        authRouter?.path.append(.anonymousOnboarding)
                    } label: {
                        Text("Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        authRouter?.path.append(.loginEmail)
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
                
                VStack(spacing: 12) {
                    Text(agreementAttributedString)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Link(destination: Config.supportURL) {
                        Text("Support")
                    }
                }
                .font(.footnote)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
                    .frame(height: 16)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppState())
}
