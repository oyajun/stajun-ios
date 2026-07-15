import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Step management
    enum Step {
        case confirm       // Username confirmation
        case sendOTP       // Send OTP
        case verifyOTP     // Verify OTP
        case deleting      // Deleting
    }

    @State private var step: Step = .confirm

    // Confirmation input
    @State private var confirmUsername = ""
    private var expectedUsername: String { appState.currentUser?.username ?? "" }
    private var isConfirmed: Bool { confirmUsername == expectedUsername }

    // OTP
    @State private var email = ""
    @State private var otp = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .confirm:
                    confirmSection
                case .sendOTP, .verifyOTP:
                    otpSection
                case .deleting:
                    deletingSection
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

    // MARK: - Sections

    @ViewBuilder
    private var confirmSection: some View {
        Section {
            Label("Cannot be undone after deletion", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text("All follow relationships and study records will be deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter '\(expectedUsername)' to confirm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Username", text: $confirmUsername)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }

        Section {
            Button("Next (Verify Identity)") {
                step = .sendOTP
            }
            .disabled(!isConfirmed)
            .foregroundStyle(.red)
        }

        if let errorMessage {
            Section {
                Text(errorMessage).foregroundStyle(.red).font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var otpSection: some View {
        Section {
            Label("We'll send an authentication code to verify your identity", systemImage: "lock.shield")
                .font(.subheadline)
        }

        if step == .sendOTP {
            Section("Email Address") {
                TextField("example@email.com", text: $email)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    #endif
            }
            Section {
                Button("Send Authentication Code") {
                    Task { await sendOTP() }
                }
                .disabled(isLoading || email.isEmpty)
            }
        } else {
            Section("Authentication Code (6 digits)") {
                TextField("000000", text: $otp)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    #endif
                    .font(.body.monospacedDigit())
                    .onChange(of: otp) { _, v in
                        otp = String(v.filter(\.isNumber).prefix(6))
                    }
            }
            Section {
                Button("Delete Account") {
                    Task { await verifyAndDelete() }
                }
                .foregroundStyle(.red)
                .disabled(isLoading || otp.count != 6)

                Button("Resend Code") {
                    Task { await sendOTP() }
                }
                .disabled(isLoading)
            }
        }

        if let errorMessage {
            Section {
                Text(errorMessage).foregroundStyle(.red).font(.subheadline)
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

    private func sendOTP() async {
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
