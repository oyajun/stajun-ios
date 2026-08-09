import SwiftUI

struct EmailInputView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthRouter.self) private var authRouter: AuthRouter?

    var mode: AuthFlowMode = .login
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
            // Header
            VStack(spacing: 8) {
                    Text("We will send a one-time passcode to your email.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .leading) {
                        if email.isEmpty {
                            Text(verbatim: "example@email.com")
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
                            Text(submitButtonText)
                                .fontWeight(.semibold)
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
            .navigationTitle(titleText)
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
                if mode == .login && email.isEmpty {
                    if let savedEmail = appState.userEmail ?? KeychainHelper.email {
                        email = savedEmail
                    }
                }
            }
        }

    private var titleText: LocalizedStringKey {
        switch mode {
        case .login: return "What's your email?"
        case .changeEmail: return "New Email"
        case .deleteAccount: return "Confirm Email"
        }
    }
    
    private var submitButtonText: LocalizedStringKey {
        switch mode {
        case .login: return "Send Authentication Code"
        case .changeEmail: return "Send Authentication Code"
        case .deleteAccount: return "Send Authentication Code"
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if mode == .login {
                try await APIClient.sendOTP(email: email)
                authRouter?.path.append(.awaitingOTP(email: email))
            } else {
                try await APIClient.requestEmailChange(newEmail: email)
                onSuccess?(email)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EmailInputView()
        .environment(AppState())
}
