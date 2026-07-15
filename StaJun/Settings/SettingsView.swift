import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    // 編集用
    @State private var username = ""
    @State private var selectedEmoji = ""
    @State private var selectedColor = ""

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isSigningOut = false
    @State private var errorMessage: String?
    @State private var showDeleteAccount = false

    private var currentUser: UserProfile? { appState.currentUser }

    var body: some View {
        NavigationStack {
            Form {
                // プロフィールプレビュー
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            UserIconView(
                                emoji: isEditing ? selectedEmoji : (currentUser?.iconEmoji ?? ""),
                                backgroundColor: isEditing ? selectedColor : (currentUser?.iconBackgroundColor ?? "#FFD54F"),
                                size: 72
                            )
                            Text(isEditing ? (username.isEmpty ? "ユーザー名" : username) : (currentUser?.username ?? ""))
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                if isEditing {
                    editSections
                } else {
                    readonlySections
                }

                // ログアウト・削除
                Section {
                    Button("ログアウト") {
                        Task { await signOut() }
                    }
                    .foregroundStyle(.red)
                    .disabled(isSigningOut)

                    Button("アカウントを削除…") {
                        showDeleteAccount = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { Task { await save() } }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { cancelEdit() }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編集") { startEdit() }
                    }
                }
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .task {
                // 最新のプロフィールを取得
                if let profile = try? await APIClient.getMyProfile() {
                    appState.updateCurrentUser(profile)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var readonlySections: some View {
        Section("ユーザー名") {
            Text(currentUser?.username ?? "")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var editSections: some View {
        Section("ユーザー名") {
            TextField("ユーザー名", text: $username)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
        Section("アイコン絵文字") {
            EmojiPickerView(selected: $selectedEmoji)
        }
        Section("アイコン背景色") {
            ColorPresetPickerView(selected: $selectedColor)
        }
        if let errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func startEdit() {
        username = currentUser?.username ?? ""
        selectedEmoji = currentUser?.iconEmoji ?? (IconPresets.emojis.first ?? "📚")
        selectedColor = currentUser?.iconBackgroundColor ?? (IconPresets.colors.first ?? "#FFD54F")
        isEditing = true
    }

    private func cancelEdit() {
        isEditing = false
        errorMessage = nil
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try await APIClient.updateProfile(
                username: trimmed.isEmpty ? nil : trimmed,
                iconEmoji: selectedEmoji.isEmpty ? nil : selectedEmoji,
                iconBackgroundColor: selectedColor.isEmpty ? nil : selectedColor
            )
            appState.updateCurrentUser(updated)
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        isSigningOut = true
        await appState.signOut()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
