import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    // For editing
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
                // Profile preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            UserIconView(
                                emoji: isEditing ? selectedEmoji : (currentUser?.iconEmoji ?? ""),
                                backgroundColor: isEditing ? selectedColor : (currentUser?.iconBackgroundColor ?? "#FFD54F"),
                                size: 72
                            )
                            Text(isEditing ? (username.isEmpty ? "Username" : username) : (currentUser?.username ?? ""))
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

                // Sign out and delete
                Section {
                    Button("Sign Out") {
                        Task { await signOut() }
                    }
                    .foregroundStyle(.red)
                    .disabled(isSigningOut)

                    Button("Delete Account…") {
                        showDeleteAccount = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancelEdit() }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { startEdit() }
                    }
                }
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .task {
                // Fetch latest profile
                if let profile = try? await APIClient.getMyProfile() {
                    appState.updateCurrentUser(profile)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var readonlySections: some View {
        Section("Username") {
            Text(currentUser?.username ?? "")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var editSections: some View {
        Section("Username") {
            TextField("Username", text: $username)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
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
