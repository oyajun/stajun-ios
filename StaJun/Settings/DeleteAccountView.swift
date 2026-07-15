import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Step management
    enum Step {
        case confirm       // Initial warning
        case verifyOTP     // Verify OTP
        case deleting      // Deleting
    }

    @State private var step: Step = .confirm

    // OTP
    @State private var otp = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var email: String? { appState.userEmail }

    var body: some View {
        NavigationStack {
            Group {
                if email == nil {
                    noEmailView
                } else {
                    Form {
                        switch step {
                        case .confirm:
                            confirmSection
                        case .verifyOTP:
                            otpSection
                        case .deleting:
                            deletingSection
                        }
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(step == .deleting)
                }
            }
        }
    }

    // MARK: - No email fallback

    private var noEmailView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Please sign out and sign in again before deleting your account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var confirmSection: some View {
        Section {
            Button("Send Authentication Code") {
                if let email {
                    Task { await sendOTP(email: email) }
                }
            }
            .foregroundStyle(.red)
            .disabled(isLoading)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("This cannot be undone. All follow relationships and study records will be deleted. We'll send an authentication code to your email to verify your identity.")
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var otpSection: some View {
        Section {
            TextField("000000", text: $otp)
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .font(.body.monospacedDigit())
                .onChange(of: otp) { _, v in
                    otp = String(v.filter(\.isNumber).prefix(6))
                }
        } header: {
            Text("Authentication Code (6 digits)")
        } footer: {
            if let email {
                Text("Enter the code sent to \(email).")
            }
        }

        Section {
            Button("Delete Account") {
                Task { await verifyAndDelete() }
            }
            .foregroundStyle(.red)
            .disabled(isLoading || otp.count != 6)

            Button("Resend Code") {
                if let email {
                    Task { await sendOTP(email: email) }
                }
            }
            .disabled(isLoading)
        } footer: {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var deletingSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Deleting…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Actions

    private func sendOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await APIClient.sendOTP(email: email)
            step = .verifyOTP
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verifyAndDelete() async {
        guard let email else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Re-authenticate with OTP to refresh session
            try await APIClient.signIn(email: email, otp: otp)
            // Delete account
            step = .deleting
            try await APIClient.deleteAccount()
            appState.clearAfterAccountDeletion()
            dismiss()
        } catch {
            step = .verifyOTP
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DeleteAccountView()
        .environment(AppState())
}
