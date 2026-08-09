import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState

    var isAnonymous: Bool = false

    @State private var name = ""
    @State private var selectedEmoji = IconPresets.emojis.first ?? "📚"
    @State private var selectedColor = IconPresets.colors.first ?? "#FFD54F"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30
    }

    var body: some View {
        Form {
                // Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            UserIconView(
                                emoji: selectedEmoji,
                                backgroundColor: selectedColor,
                                size: 80
                            )
                            Text(name.isEmpty ? "Name" : name)
                                .font(.headline)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Name
                Section("Name") {
                    TextField("e.g., Alex", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Icon emoji
                Section("Icon Emoji") {
                    EmojiPickerView(selected: $selectedEmoji)
                }

                // Background color
                Section("Icon Background Color") {
                    ColorPresetPickerView(selected: $selectedColor)
                }

                // Error
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { await submit() }
                    }
                    .disabled(!isValid || isLoading)
                    .overlay {
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        }
                }
            }
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if isAnonymous {
                try await appState.createAnonymousProfile(
                    name: trimmedName,
                    iconEmoji: selectedEmoji,
                    iconBackgroundColor: selectedColor
                )
            } else {
                let profile = try await APIClient.updateProfile(
                    name: trimmedName,
                    iconEmoji: selectedEmoji,
                    iconBackgroundColor: selectedColor
                )
                appState.completeOnboarding(profile: profile)
            }
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AppState())
}
