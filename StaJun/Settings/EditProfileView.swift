import SwiftUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var selectedEmoji = ""
    @State private var selectedColor = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currentUser: UserProfile? { appState.currentUser }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        UserIconView(
                            emoji: selectedEmoji,
                            backgroundColor: selectedColor,
                            size: 80
                        )
                        Text(username.isEmpty ? "Username" : username)
                            .font(.headline)
                            .foregroundStyle(username.isEmpty ? .secondary : .primary)
                    }
                    Spacer()
                }
                .padding(.vertical, 24)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemGray6))

                Section("Username") {
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Icon Emoji") {
                    EmojiPickerView(selected: $selectedEmoji)
                }

                Section("Icon Background Color") {
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
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                username = currentUser?.username ?? ""
                selectedEmoji = currentUser?.iconEmoji ?? (IconPresets.emojis.first ?? "📚")
                selectedColor = currentUser?.iconBackgroundColor ?? (IconPresets.colors.first ?? "#FFD54F")
            }
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try await APIClient.updateProfile(
                username: trimmed.isEmpty ? nil : trimmed,
                iconEmoji: selectedEmoji.isEmpty ? nil : selectedEmoji,
                iconBackgroundColor: selectedColor.isEmpty ? nil : selectedColor
            )
            appState.updateCurrentUser(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EditProfileView()
        .environment(AppState())
}
