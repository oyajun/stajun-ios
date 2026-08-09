import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showOTP = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var email: String? { appState.userEmail }

    var body: some View {
        NavigationStack {
            Group {
                if appState.currentUser?.isAnonymous == true {
                    anonymousDeleteView
                } else if email == nil {
                    noEmailView
                } else {
                    confirmView
                }
            }
            .navigationDestination(isPresented: $showOTP) {
                if let email {
                    OTPInputView(
                        email: email,
                        mode: .deleteAccount,
                        onSuccess: {
                            dismiss()
                        },
                        onCancel: {
                            dismiss() // Cancels the whole modal
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - No email fallback

    private var noEmailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Please sign out and sign in again before deleting your account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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

    // MARK: - Sections

    private var confirmView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                Text("This cannot be undone.\nAll follow relationships and study records will be deleted.\nWe'll send an authentication code to your email to verify your identity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                if let email {
                    Task { await sendOTP(email: email) }
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Delete Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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

    private var anonymousDeleteView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                Text("This cannot be undone.\nAll follow relationships and study records will be deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                Task { await deleteAnonymousUser() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Delete Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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

    // MARK: - Actions

    private func sendOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.sendOTP(email: email, mode: .deleteAccount)
            showOTP = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAnonymousUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await APIClient.deleteAnonymousAccount()
            appState.clearAfterAccountDeletion()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DeleteAccountView()
        .environment(AppState())
}
