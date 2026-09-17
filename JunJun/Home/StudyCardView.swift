import SwiftUI
import UIKit

struct StudyCardView: View {
    let currentUser: UserProfile?
    let isPro: Bool
    let viewModel: HomeViewModel
    let onTapUser: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 40) {
            // Left: own icon + name
            Button {
                onTapUser()
            } label: {
                VStack(spacing: 0) {
                    UserIconView(
                        emoji: currentUser?.iconEmoji ?? "📚",
                        backgroundColor: currentUser?.iconBackgroundColor ?? "#FFD54F",
                        size: 52,
                        isStudying: viewModel.isStudying,
                        isPro: isPro
                    )
                    Text(currentUser?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.top, 14)
                }
            }
            .buttonStyle(.plain)
            .animation(nil, value: viewModel.isStudying)

            // Right: timer + controls
            VStack(spacing: 12) {
                HStack {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        Text(viewModel.isStudying ? HomeTimeFormatter.formatElapsed(seconds: LocalStudyStore.totalElapsedSeconds(at: context.date)) : "--:--")
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(viewModel.isStudying ? (viewModel.isPaused ? Color.secondary : Color.orange) : Color.secondary)
                    }
                    Spacer()
                    Text(viewModel.isStudying ? (viewModel.isPaused ? LocalizedStringKey("Paused") : LocalizedStringKey("Studying")) : LocalizedStringKey("Not Studying"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.isStudying {
                    actionButton(title: "Start") {
                        Task { await viewModel.startStudying() }
                    }
                } else if viewModel.isPaused {
                    actionButton(title: "Resume") {
                        Task { await viewModel.resumeStudying() }
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            Task { await viewModel.pauseStudying() }
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.subheadline.bold())
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(LocalizedStringKey("Pause"))
                        .disabled(viewModel.studyActionLoading)

                        actionButton(title: "Stop", tint: .red) {
                            viewModel.stopStudying()
                        }
                    }
                    .background {
                        StudyingButtonGlow(
                            backgroundColor: currentUser?.iconBackgroundColor ?? "#FFD54F",
                            isPro: isPro
                        )
                        .opacity(1)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isStudying)
                    }
                }

                if let studyError = viewModel.studyError {
                    Text(studyError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func actionButton(
        title: LocalizedStringKey,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            action()
        } label: {
            Group {
                if viewModel.studyActionLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .disabled(viewModel.studyActionLoading)
    }
}
