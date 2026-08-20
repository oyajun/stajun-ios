import SwiftUI

enum ProfileFormMode: Hashable {
    case edit
    case create(isAnonymous: Bool)
}

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var mode: ProfileFormMode = .edit

    @State private var name = ""
    @State private var selectedEmoji = IconPresets.emojis.first ?? "📚"
    @State private var selectedColor = IconPresets.colors.first ?? "#FFD54F"

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currentUser: UserProfile? { appState.currentUser }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCreateMode {
            return !trimmed.isEmpty && trimmed.count <= 30
        }
        return trimmed.count <= 30
    }

    var body: some View {
        if isCreateMode {
            formContent
                .navigationTitle("Create Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            Task { await save() }
                        }
                        .disabled(!isValid || isLoading)
                        .overlay {
                            if isLoading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                }
                .onAppear(perform: initializeValues)
        } else {
            NavigationStack {
                formContent
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task { await save() }
                            }
                            .disabled(!isValid || isLoading)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                    .onAppear(perform: initializeValues)
            }
        }
    }

    private var formContent: some View {
        Form {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    UserIconView(
                        emoji: selectedEmoji,
                        backgroundColor: selectedColor,
                        size: 80
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                    Text(name.isEmpty ? "Name" : name)
                        .font(.title2.bold())
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)
                }
                Spacer()
            }
            .padding(.top, 0)
            .padding(.bottom, 0)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section("Name") {
                TextField(isCreateMode ? "e.g., Alex" : "Name", text: $name)
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
    }

    private func initializeValues() {
        if case .create = mode {
            name = ""
            selectedEmoji = IconPresets.emojis.first ?? "📚"
            selectedColor = IconPresets.colors.first ?? "#FFD54F"
        } else {
            name = currentUser?.name ?? ""
            selectedEmoji = currentUser?.iconEmoji ?? (IconPresets.emojis.first ?? "📚")
            selectedColor = currentUser?.iconBackgroundColor ?? (IconPresets.colors.first ?? "#FFD54F")
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            switch mode {
            case .create(let isAnonymous):
                if isAnonymous {
                    try await appState.createAnonymousProfile(
                        name: trimmed,
                        iconEmoji: selectedEmoji,
                        iconBackgroundColor: selectedColor
                    )
                } else {
                    let profile = try await APIClient.updateProfile(
                        name: trimmed,
                        iconEmoji: selectedEmoji,
                        iconBackgroundColor: selectedColor
                    )
                    appState.completeOnboarding(profile: profile)
                }
            case .edit:
                let updated = try await APIClient.updateProfile(
                    name: trimmed.isEmpty ? nil : trimmed,
                    iconEmoji: selectedEmoji.isEmpty ? nil : selectedEmoji,
                    iconBackgroundColor: selectedColor.isEmpty ? nil : selectedColor
                )
                appState.updateCurrentUser(updated)
                dismiss()
            }
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environment(AppState())
}
