import SwiftUI

struct EmailInputView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthRouter.self) private var authRouter: AuthRouter?

    var mode: AuthFlowMode = .login
    var customTitle: String? = nil
    var customDescription: String? = nil
    var customPlaceholder: String? = nil
    var customButtonText: String? = nil
    var onSuccess: ((String) -> Void)? = nil

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValidEmail: Bool {
        let pattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/
        return email.wholeMatch(of: pattern) != nil
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header Description
            VStack(spacing: 8) {
                if let customDescription {
                    Text(customDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(defaultDescriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            // Email input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    if email.isEmpty {
                        Text(verbatim: customPlaceholder ?? "example@email.com")
                            .foregroundStyle(Color(white: 0.6))
                            .padding(.horizontal, 16)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $email)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .foregroundStyle(.primary)
                        .tint(.primary)
                        .padding()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Send button
            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        if let customButtonText {
                            Text(customButtonText)
                                .fontWeight(.semibold)
                        } else {
                            Text(defaultSubmitButtonText)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidEmail || isLoading)
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if mode != .login {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                    .tint(.primary)
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            if (mode == .login || mode == .registerEmail) && email.isEmpty {
                if let savedEmail = appState.userEmail ?? KeychainHelper.email {
                    email = savedEmail
                }
            }
        }
    }

    private var displayTitle: String {
        if let customTitle {
            return customTitle
        }
        switch mode {
        case .login:
            return String(localized: "Sign In")
        case .registerEmail:
            return String(localized: "Register Email Address")
        case .changeEmail:
            return String(localized: "Change Email Address")
        case .deleteAccount:
            return String(localized: "Confirm Email")
        }
    }

    private var defaultDescriptionText: LocalizedStringKey {
        switch mode {
        case .login: return "Please enter your registered email address."
        case .registerEmail: return "Please enter the email address you want to register."
        case .changeEmail: return "Please enter your new email address."
        case .deleteAccount: return "We will send a one-time passcode to your email."
        }
    }

    private var defaultSubmitButtonText: LocalizedStringKey {
        switch mode {
        case .login, .registerEmail, .changeEmail, .deleteAccount:
            return "Send Authentication Code"
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.sendOTP(email: email, mode: mode)
            if let authRouter {
                authRouter.path.append(.awaitingOTP(email: email, mode: mode))
            }
            onSuccess?(email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EmailInputView()
        .environment(AppState())
}
