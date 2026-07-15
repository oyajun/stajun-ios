import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // ステップ管理
    enum Step {
        case confirm       // username 入力確認
        case sendOTP       // OTP 送信
        case verifyOTP     // OTP 入力
        case deleting      // 削除中
    }

    @State private var step: Step = .confirm

    // 確認入力
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
            .navigationTitle("アカウントを削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(step == .deleting)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var confirmSection: some View {
        Section {
            Label("削除後は取り消せません", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text("フォロー関係・学習記録がすべて削除されます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("確認のため「\(expectedUsername)」と入力してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("ユーザー名", text: $confirmUsername)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }

        Section {
            Button("次へ（本人確認）") {
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
            Label("本人確認のため認証コードを送信します", systemImage: "lock.shield")
                .font(.subheadline)
        }

        if step == .sendOTP {
            Section("メールアドレス") {
                TextField("example@email.com", text: $email)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    #endif
            }
            Section {
                Button("認証コードを送信") {
                    Task { await sendOTP() }
                }
                .disabled(isLoading || email.isEmpty)
            }
        } else {
            Section("認証コード（6桁）") {
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
                Button("アカウントを削除する") {
                    Task { await verifyAndDelete() }
                }
                .foregroundStyle(.red)
                .disabled(isLoading || otp.count != 6)

                Button("コードを再送信") {
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
                    Text("削除中…")
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
            // OTP 再認証（セッションをフレッシュにする）
            try await APIClient.signIn(email: email, otp: otp)
            // アカウント削除
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
