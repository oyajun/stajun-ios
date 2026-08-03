import SwiftUI

struct ChangeEmailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Step {
        case inputEmail
        case verifyOTP
        case changing
    }

    @State private var step: Step = .inputEmail
    
    @State private var newEmail = ""
    @State private var otp = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isValidEmail: Bool {
        let pattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/
        return newEmail.wholeMatch(of: pattern) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .inputEmail:
                    inputEmailSection
                case .verifyOTP:
                    otpSection
                case .changing:
                    changingSection
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(step == .changing)
                }
            }
        }
    }
    
    // MARK: - Sections

    @ViewBuilder
    private var inputEmailSection: some View {
        Section {
            TextField("New Email Address", text: $newEmail)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
        } header: {
            Text("New Email")
        } footer: {
            Text("We'll send an authentication code to this email to verify it.")
        }
        
        Section {
            Button("Send Authentication Code") {
                Task { await sendOTP() }
            }
            .disabled(isLoading || !isValidEmail)
        } footer: {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
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
            Text("Enter the code sent to \(newEmail).")
        }

        Section {
            Button("Change Email") {
                Task { await verifyAndChange() }
            }
            .disabled(isLoading || otp.count != 6)

            Button("Resend Code") {
                Task { await sendOTP() }
            }
            .disabled(isLoading)
        } footer: {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var changingSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Changing…")
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
            try await APIClient.requestEmailChange(newEmail: newEmail)
            step = .verifyOTP
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verifyAndChange() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            step = .changing
            try await APIClient.changeEmail(newEmail: newEmail, otp: otp)
            appState.userEmail = newEmail
            dismiss()
        } catch {
            step = .verifyOTP
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ChangeEmailView()
        .environment(AppState())
}
