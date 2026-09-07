import SwiftUI
import UIKit

// MARK: - Tail Direction

enum BubbleTailDirection: Sendable {
    case up   // Tail points upward (for bubble below the avatar)
    case down // Tail points downward (for bubble above the avatar)
}

// MARK: - Unified Speech Bubble Shape (Single Continuous Path)

struct SpeechBubbleShape: Shape {
    let cornerRadius: CGFloat
    let tailDirection: BubbleTailDirection
    var tailX: CGFloat? = nil
    let tailWidth: CGFloat
    let tailHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bodyRect: CGRect
        switch tailDirection {
        case .up:
            bodyRect = CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        case .down:
            bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        }

        let r = min(cornerRadius, bodyRect.height / 2, bodyRect.width / 2)
        let tWidth = tailWidth
        let targetTailX = tailX ?? rect.midX
        let clampedTailX = max(bodyRect.minX + r + tWidth / 2, min(bodyRect.maxX - r - tWidth / 2, targetTailX))

        switch tailDirection {
        case .up:
            // Start at top-left corner
            path.move(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY))

            // Top edge with upward tail
            path.addLine(to: CGPoint(x: clampedTailX - tWidth / 2, y: bodyRect.minY))
            path.addLine(to: CGPoint(x: clampedTailX, y: rect.minY))
            path.addLine(to: CGPoint(x: clampedTailX + tWidth / 2, y: bodyRect.minY))
            path.addLine(to: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY))

            // Top-right corner
            path.addArc(
                center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY + r),
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            // Right edge
            path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - r))
            // Bottom-right corner
            path.addArc(
                center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.maxY - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            // Bottom edge
            path.addLine(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY))
            // Bottom-left corner
            path.addArc(
                center: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY - r),
                radius: r,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Left edge
            path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + r))
            // Top-left corner
            path.addArc(
                center: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY + r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        case .down:
            // Start at top-left corner
            path.move(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY))
            // Top edge
            path.addLine(to: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY))
            // Top-right corner
            path.addArc(
                center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY + r),
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            // Right edge
            path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - r))
            // Bottom-right corner
            path.addArc(
                center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.maxY - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )

            // Bottom edge with downward tail
            path.addLine(to: CGPoint(x: clampedTailX + tWidth / 2, y: bodyRect.maxY))
            path.addLine(to: CGPoint(x: clampedTailX, y: rect.maxY))
            path.addLine(to: CGPoint(x: clampedTailX - tWidth / 2, y: bodyRect.maxY))
            path.addLine(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY))

            // Bottom-left corner
            path.addArc(
                center: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY - r),
                radius: r,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Left edge
            path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + r))
            // Top-left corner
            path.addArc(
                center: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY + r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Following Activity Bubble (iMessage Pinned Message Style)

struct FollowingActivityBubble: View {
    let text: String
    let isTop: Bool
    let extendsRight: Bool

    static let minBubbleWidth: CGFloat = 40  // Compact minimum width for short words (1-2 chars)
    static let maxBubbleWidth: CGFloat = 157 // Up to the outer glow edge of neighbor's avatar (71.5 + 14 + 71.5 = 157)
    static let cellWidth: CGFloat = 74
    static let singleCellMaxWidth: CGFloat = 69 // Avatar + glow width (52 * 1.32 ≈ 69)

    private let tailWidth: CGFloat = 12
    private let tailHeight: CGFloat = 8
    private let avatarOffsetFromEdge: CGFloat = 34.5 // From glow edge (2.5pt) to avatar center (37pt)

    static func calculateWidth(for text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let desired = textWidth + 16 // 8pt padding on each side (tight & balanced)
        return min(max(desired, minBubbleWidth), maxBubbleWidth)
    }

    /// Whether the bubble exceeds one cell width and occupies the neighbor slot.
    static func occupiesNeighbor(for text: String) -> Bool {
        calculateWidth(for: text) > cellWidth
    }

    /// Whether the bubble fits compactly within the avatar's glow width (centered directly over avatar).
    static func isSingleCell(for text: String) -> Bool {
        calculateWidth(for: text) <= singleCellMaxWidth
    }

    private var bubbleWidth: CGFloat {
        Self.calculateWidth(for: text)
    }

    private var isSingleCell: Bool {
        Self.isSingleCell(for: text)
    }

    private var tailX: CGFloat {
        if isSingleCell {
            // Centered directly over the avatar (tail points straight to avatar center)
            return bubbleWidth / 2
        } else if extendsRight {
            // Leading edge aligns with avatar glow leading edge (2.5pt in cell).
            // Tail is 34.5pt from bubble leading edge -> aligns with avatar center (37pt in cell).
            return avatarOffsetFromEdge
        } else {
            // Trailing edge aligns with avatar glow trailing edge (71.5pt in cell).
            // Tail is 34.5pt from bubble trailing edge -> aligns with avatar center (37pt in cell).
            return bubbleWidth - avatarOffsetFromEdge
        }
    }

    private var tailDirection: BubbleTailDirection {
        isTop ? .down : .up
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium)) // Same size as user name
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.top, isTop ? 6 : tailHeight + 6)
            .padding(.bottom, isTop ? tailHeight + 6 : 6)
            .frame(width: bubbleWidth, height: 36, alignment: .center)
            .background {
                SpeechBubbleShape(
                    cornerRadius: 11,
                    tailDirection: tailDirection,
                    tailX: tailX,
                    tailWidth: tailWidth,
                    tailHeight: tailHeight
                )
                .fill(.ultraThinMaterial)
                .overlay {
                    SpeechBubbleShape(
                        cornerRadius: 11,
                        tailDirection: tailDirection,
                        tailX: tailX,
                        tailWidth: tailWidth,
                        tailHeight: tailHeight
                    )
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
            }
    }
}

// MARK: - My Activity Bubble (Shown under my profile card when studying)

struct MyActivityBubble: View {
    let activity: String?
    var tailX: CGFloat = 26
    let onEdit: () -> Void

    private let tailWidth: CGFloat = 12
    private let tailHeight: CGFloat = 8

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 6) {
                if let activity, !activity.isEmpty {
                    Text(activity)
                        .font(.caption.weight(.medium)) // Same size as user name
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Tap to add what you are doing")
                        .font(.caption.weight(.medium)) // Same size as user name
                        .foregroundStyle(Color.accentColor) // Blue text!
                }

                Image(systemName: "pencil")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(activity == nil || activity?.isEmpty == true ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, tailHeight + 6)
            .padding(.bottom, 6)
            .background {
                SpeechBubbleShape(
                    cornerRadius: 13,
                    tailDirection: .up,
                    tailX: tailX,
                    tailWidth: tailWidth,
                    tailHeight: tailHeight
                )
                .fill(.ultraThinMaterial)
                .overlay {
                    SpeechBubbleShape(
                        cornerRadius: 13,
                        tailDirection: .up,
                        tailX: tailX,
                        tailWidth: tailWidth,
                        tailHeight: tailHeight
                    )
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Activity Bubble (Shown above avatar in UserProfileView)

struct ProfileActivityBubble: View {
    let activity: String?
    let isOwnProfile: Bool
    var onEdit: (() -> Void)? = nil

    private let tailWidth: CGFloat = 12
    private let tailHeight: CGFloat = 8

    var body: some View {
        if isOwnProfile {
            Button {
                onEdit?()
            } label: {
                bubbleContent
            }
            .buttonStyle(.plain)
        } else if let activity = activity?.trimmingCharacters(in: .whitespacesAndNewlines), !activity.isEmpty {
            bubbleContent
        }
    }

    private var bubbleContent: some View {
        HStack(spacing: 6) {
            if let activity = activity?.trimmingCharacters(in: .whitespacesAndNewlines), !activity.isEmpty {
                Text(activity)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tap to add what you are doing")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if isOwnProfile {
                Image(systemName: "pencil")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(activity == nil || activity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? Color.accentColor : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, tailHeight + 7)
        .background {
            SpeechBubbleShape(
                cornerRadius: 13,
                tailDirection: .down,
                tailWidth: tailWidth,
                tailHeight: tailHeight
            )
            .fill(.ultraThinMaterial)
            .overlay {
                SpeechBubbleShape(
                    cornerRadius: 13,
                    tailDirection: .down,
                    tailWidth: tailWidth,
                    tailHeight: tailHeight
                )
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
        }
    }
}
