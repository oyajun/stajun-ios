import SwiftUI

struct EmailInputView: View {
    @Environment(AppState.self) private var appState

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValidEmail: Bool {
        let pattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/
        return email.wholeMatch(of: pattern) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // ロゴ・タイトル
                VStack(spacing: 8) {
                    Text("StaJun")
                        .font(.largeTitle.bold())
                    Text("What are you studying now?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // メール入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("メールアドレス")
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

                // エラー
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 送信ボタン
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("認証コードを送信")
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
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.requestOTP(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EmailInputView()
        .environment(AppState())
}
