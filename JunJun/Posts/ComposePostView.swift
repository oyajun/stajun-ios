import SwiftUI

/// Sheet for creating a study-time post.
/// Study time is entered manually (minutes); when presented after stopping a
/// live session, the elapsed minutes can be passed as `initialMinutes`.
struct ComposePostView: View {
    /// Called with the created post after a successful submission.
    var onPosted: ((StudyPost) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var hours: Int
    @State private var mins: Int
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let maxCommentLength = 500

    init(initialMinutes: Int = 0, onPosted: ((StudyPost) -> Void)? = nil) {
        self.onPosted = onPosted
        let clamped = min(max(initialMinutes, 0), 1440)
        _hours = State(initialValue: clamped / 60)
        _mins = State(initialValue: clamped % 60)
    }

    private var totalMinutes: Int { hours * 60 + mins }

    private var durationText: LocalizedStringKey { "\(hours)h \(mins)m" }

    private var isValid: Bool {
        (1...1440).contains(totalMinutes) && comment.count <= maxCommentLength
    }

    /// Cap total study time at 24h (1440 min).
    private func clampDuration() {
        if hours >= 24 {
            hours = 24
            mins = 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0...24, id: \.self) { h in
                                Text("\(h) h").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Minutes", selection: $mins) {
                            ForEach(0...59, id: \.self) { m in
                                Text("\(m) m").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)
                    .clipped()
                    .onChange(of: hours) { _, _ in clampDuration() }
                    .onChange(of: mins) { _, _ in clampDuration() }
                } header: {
                    HStack {
                        Text("Study Time")
                        Spacer()
                        Text(durationText)
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    TextField("What did you study?", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    HStack {
                        Text("Comment (optional)")
                        Spacer()
                        Text("\(comment.count)/\(maxCommentLength)")
                            .foregroundStyle(comment.count > maxCommentLength ? .red : .secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task { await submit() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let post = try await APIClient.createPost(minutes: totalMinutes, comment: comment)
            onPosted?(post)
            dismiss()
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ComposePostView(initialMinutes: 45)
}
