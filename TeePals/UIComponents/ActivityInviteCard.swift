import SwiftUI

/// Invite card for Activity > Invites tab.
/// Shows round info with inviter details and Accept/Decline actions.
struct ActivityInviteCard: View {

    let dateMonth: String
    let dateDay: String
    let courseName: String
    let inviterName: String
    let inviterPhotoURL: URL?
    let onTap: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: AppSpacingV3.md) {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)

            actionButtons
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .cornerRadius(AppSpacingV3.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                .stroke(AppColorsV3.borderLight, lineWidth: 1)
        )
        .premiumShadow()
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(alignment: .center, spacing: AppSpacingV3.md) {
            dateBadge
            roundInfo
            Spacer()
        }
        .frame(minHeight: 52)
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(dateMonth)
                .font(AppTypographyV3.labelTiny)
                .textCase(.uppercase)
                .tracking(-0.5)
                .foregroundColor(AppColorsV3.textSecondary)

            Text(dateDay)
                .font(AppTypographyV3.numberMediumSerif)
                .foregroundColor(AppColorsV3.forestGreen)
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                .fill(Color.gray.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                        .stroke(AppColorsV3.borderLight, lineWidth: 1)
                )
        )
    }

    private var roundInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(courseName)
                .font(AppTypographyV3.roundCardTitle)
                .foregroundColor(AppColorsV3.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppSpacingV3.xs) {
                if let photoURL = inviterPhotoURL {
                    AsyncImage(url: photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 16, height: 16)
                    .clipped()
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }

                Text("Invited by \(inviterName)")
                    .font(AppTypographyV3.bodySmall)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppSpacingV3.sm) {
            Button(action: onDecline) {
                Text("Decline")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                            .stroke(AppColorsV3.borderLight, lineWidth: 1)
                    )
                    .cornerRadius(AppSpacingV3.radiusButton)
            }
            .buttonStyle(.plain)

            Button(action: onAccept) {
                Text("Accept")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColorsV3.forestGreen)
                    .cornerRadius(AppSpacingV3.radiusButton)
                    .shadow(color: AppColorsV3.forestGreen.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ActivityInviteCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ActivityInviteCard(
                dateMonth: "Feb",
                dateDay: "15",
                courseName: "Riverwalk Golf Club",
                inviterName: "Sarah M.",
                inviterPhotoURL: nil,
                onTap: {},
                onAccept: {},
                onDecline: {}
            )

            ActivityInviteCard(
                dateMonth: "Feb",
                dateDay: "18",
                courseName: "Sunnyvale Municipal",
                inviterName: "David K.",
                inviterPhotoURL: nil,
                onTap: {},
                onAccept: {},
                onDecline: {}
            )
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
