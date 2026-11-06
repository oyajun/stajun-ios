import SwiftUI

struct ActivityEditSheet: View {
    let initialActivity: String?
    let onSave: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var text: String
    @State private var showPaywall = false
    @FocusState private var isFocused: Bool

    private let maxLength = 50

    init(
        initialActivity: String?,
        onSave: @escaping (String?) -> Void
    ) {
        self.initialActivity = initialActivity
        self.onSave = onSave
        _text = State(initialValue: initialActivity ?? "")
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        text.count <= maxLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What are you doing?", text: $text)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValid {
                                saveAndDismiss()
                            }
                        }
                } footer: {
                    HStack {
                        Spacer()
                        Text("\(text.count)/\(maxLength)")
                            .font(.caption2)
                            .foregroundStyle(text.count > maxLength ? .red : .secondary)
                    }
                }

                if Config.showAds && !appState.isPro {
                    Section {
                        CompactNativeAdCard()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .navigationTitle(Text("Status"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .environment(\.openPaywall) {
                showPaywall = true
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                isFocused = true
            }
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                isFocused = true
            }
        }
    }

    private func saveAndDismiss() {
        let result = trimmed.isEmpty ? nil : trimmed
        onSave(result)
        dismiss()
    }
}
