import SwiftUI

struct OTPInputView: View {
    let email: String
    var mode: AuthFlowMode = .login
    var customTitle: String? = nil
    var customDescription: String? = nil
    var customButtonText: String? = nil
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
                if let customDescription {
                    Text(customDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Enter the code sent to \(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
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
                        if let customButtonText {
                            Text(customButtonText)
                                .fontWeight(.semibold)
                        } else {
                            Text(defaultVerifyButtonText)
                                .fontWeight(.semibold)
                        }
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
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if mode != .login {
                    Button {
                        if let onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private var displayTitle: String {
        if let customTitle {
            return customTitle
        }
        return String(localized: "Enter Authentication Code")
    }

    private var defaultVerifyButtonText: LocalizedStringKey {
        switch mode {
        case .login, .registerEmail, .changeEmail:
            return "Verify"
        case .deleteAccount:
            return "Delete Account"
        }
    }

    private func verify() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.verifyOTP(email: email, otp: otp, mode: mode)
            onSuccess?()
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resend() async {
        isResending = true
        errorMessage = nil
        defer { isResending = false }
        do {
            try await appState.resendOTP(email: email, mode: mode)
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    OTPInputView(email: "test@example.com")
        .environment(AppState())
}
