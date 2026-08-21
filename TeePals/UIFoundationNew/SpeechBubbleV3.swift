import SwiftUI

/// Speech Bubble V3 - Host message with optional avatar/initials
/// Used for displaying host message in round creation review
struct SpeechBubbleV3: View {

    let message: String
    let initials: String?
    let onEdit: (() -> Void)?

    init(message: String, initials: String? = nil, onEdit: (() -> Void)? = nil) {
        self.message = message
        self.initials = initials
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacingV3.sm) {
            if let initials = initials, !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(width: 32, height: 32)
                    .background(AppColorsV3.forestGreen.opacity(0.12))
                    .clipShape(Circle())
            }

            bubbleContent
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let hasAvatar = initials?.isEmpty == false
        if hasAvatar {
            messageView
                .clipShape(SpeechBubbleShape())
        } else {
            messageView
                .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        }
    }

    private var messageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message)
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColorsV3.forestGreen)
                }
                .padding(.top, AppSpacingV3.xs)
            }
        }
        .padding(AppSpacingV3.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorsV3.surfaceWhite)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

/// Rounded rect with a small tail on the left (speech bubble)
private struct SpeechBubbleShape: Shape {
    private let radius: CGFloat = AppSpacingV3.radiusSmall
    private let tailSize: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, rect.height / 2, rect.width / 2)
        let tailY = rect.minY + 24

        let mainRect = CGRect(
            x: rect.minX + tailSize,
            y: rect.minY,
            width: rect.width - tailSize,
            height: rect.height
        )
        path.addRoundedRect(in: mainRect, cornerSize: CGSize(width: r, height: r))

        path.move(to: CGPoint(x: rect.minX + tailSize, y: tailY - tailSize))
        path.addLine(to: CGPoint(x: rect.minX, y: tailY))
        path.addLine(to: CGPoint(x: rect.minX + tailSize, y: tailY + tailSize))
        path.closeSubpath()

        return path
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        SpeechBubbleV3(
            message: "Looking for a relaxed round. Happy to pair with anyone!",
            initials: "JD",
            onEdit: {}
        )

        SpeechBubbleV3(
            message: "Casual 18 holes, all skill levels welcome.",
            onEdit: nil
        )
    }
    .padding()
    .background(AppColorsV3.bgNeutral)
}
#endif
