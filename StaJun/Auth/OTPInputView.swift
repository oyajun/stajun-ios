import SwiftUI

struct OTPInputView: View {
    let email: String

    @Environment(AppState.self) private var appState

    @State private var otp = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?

    private var isValidOTP: Bool { otp.count == 6 && otp.allSatisfy(\.isNumber) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("📨")
                        .font(.system(size: 64))
                    Text("認証コードを入力")
                        .font(.title2.bold())
                    Text("\(email) に送信したコードを入力してください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // OTP 入力フィールド
                VStack(alignment: .leading, spacing: 8) {
                    Text("6桁のコード")
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

                // エラー
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 確認ボタン
                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("確認")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidOTP || isLoading)
                .padding(.horizontal)

                // 再送信
                Button {
                    Task { await resend() }
                } label: {
                    if isResending {
                        ProgressView()
                    } else {
                        Text("コードを再送信")
                            .font(.subheadline)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isResending)

                // 戻る
                Button {
                    appState.authState = .unauthenticated
                } label: {
                    Text("メールアドレスを変更")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private func verify() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.verifyOTP(email: email, otp: otp)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resend() async {
        isResending = true
        errorMessage = nil
        defer { isResending = false }
        do {
            try await appState.requestOTP(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    OTPInputView(email: "test@example.com")
        .environment(AppState())
}
