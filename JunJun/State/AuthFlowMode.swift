import Foundation

// MARK: - AuthFlowMode

enum AuthFlowMode: Equatable, Hashable {
    case login          // ログイン (Sign In)
    case registerEmail  // メールアドレスの登録 (Register Email Address)
    case changeEmail    // メールアドレスの変更 (Change Email Address)
    case deleteAccount  // アカウント削除 (Delete Account / Confirm Email)
}
