import SwiftUI

struct OTPInputView: View {
    let email: String
    var mode: AuthFlowMode = .login
    var onSuccess: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var otp = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?

    private var isValidOTP: Bool { otp.count == 6 && otp.allSatisfy(\.isNumber) }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                    Text("📨")
                        .font(.system(size: 64))
                    Text("Enter the code sent to \(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // OTP input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("6-Digit Code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("000000", text: $otp)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        #endif
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: otp) { _, val in
                            otp = String(val.filter(\.isNumber).prefix(6))
                        }
                }
                .padding(.horizontal)

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            let verifyText: LocalizedStringKey = {
                                switch mode {
                                case .login, .registerEmail, .changeEmail: return "Verify"
                                case .deleteAccount: return "Delete Account"
                                }
                            }()
                            Text(verifyText)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode == .deleteAccount ? .red : nil)
                .disabled(!isValidOTP || isLoading)
                .padding(.horizontal)

                // Resend / Change email
                HStack(spacing: 24) {
                    Button {
                        Task { await resend() }
                    } label: {
                        if isResending {
                            ProgressView()
                        } else {
                            Text("Resend Code")
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .disabled(isResending)
                }

                Spacer()
            }
            .navigationTitle("Enter Authentication Code")
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
                    }
                }
            }
        }

    private func verify() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .login, .registerEmail:
                try await appState.verifyOTP(email: email, otp: otp)
            case .changeEmail:
                try await APIClient.changeEmail(newEmail: email, otp: otp)
                appState.userEmail = email
                if let current = appState.currentUser {
                    let updated = UserProfile(
                        id: current.id,
                        name: current.name,
                        iconEmoji: current.iconEmoji,
                        iconBackgroundColor: current.iconBackgroundColor,
                        isAnonymous: false,
                        email: email
                    )
                    appState.updateCurrentUser(updated)
                }
                onSuccess?()
            case .deleteAccount:
                try await APIClient.signIn(email: email, otp: otp)
                try await APIClient.deleteAccount()
                appState.clearAfterAccountDeletion()
                onSuccess?()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resend() async {
        isResending = true
        errorMessage = nil
        defer { isResending = false }
        do {
            switch mode {
            case .login, .registerEmail, .deleteAccount:
                try await appState.requestOTP(email: email)
            case .changeEmail:
                try await APIClient.requestEmailChange(newEmail: email)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    OTPInputView(email: "test@example.com")
        .environment(AppState())
}
