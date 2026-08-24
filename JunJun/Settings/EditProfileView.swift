import SwiftUI

enum ProfileFormMode: Hashable {
    case edit
    case create(isAnonymous: Bool)
}

enum IconTab: String, CaseIterable, Identifiable {
    case emoji
    case background

    var id: String { rawValue }
}

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var mode: ProfileFormMode = .edit

    @State private var name = ""
    @State private var selectedEmoji = IconPresets.emojis.first ?? "📚"
    @State private var selectedColor = IconPresets.colors.first ?? "#FFD54F"
    @State private var selectedTab: IconTab = .emoji

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
                            .overlay {
                                if isLoading {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                    .onAppear(perform: initializeValues)
            }
            .interactiveDismissDisabled()
        }
    }

    private var formContent: some View {
        Form {
            // Name Field
            Section("Name") {
                HStack {
                    TextField(isCreateMode ? "e.g., Alex" : "Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !name.isEmpty {
                        Text(verbatim: "\(name.count)/30")
                            .font(.caption2)
                            .foregroundStyle(name.count > 30 ? Color.red : Color.secondary)
                    }
                }
            }

            // Icon Customization Section (Preview in Header, Tabs & Picker in Card)
            Section {
                VStack(spacing: 8) {
                    // Segmented Tabs: Emoji | Background Color
                    Picker("Icon Settings", selection: $selectedTab) {
                        Label("Emoji", systemImage: "face.smiling")
                            .tag(IconTab.emoji)
                        Label("Background Color", systemImage: "paintpalette")
                            .tag(IconTab.background)
                    }
                    .pickerStyle(.segmented)

                    // Selection View
                    switch selectedTab {
                    case .emoji:
                        EmojiPickerView(selected: $selectedEmoji)
                    case .background:
                        ColorPresetPickerView(selected: $selectedColor)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Icon")

                    HStack {
                        Spacer()
                        UserIconView(
                            emoji: selectedEmoji,
                            backgroundColor: selectedColor,
                            size: 88
                        )
                        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                        Spacer()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
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
