import SwiftUI

/// Card for invited rounds showing inviter and Accept/Decline actions.
struct InvitedRoundCard: View {

    let round: Round
    let inviterName: String?
    let onTap: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Main round content (tappable)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    // Header: Title + Spots
                    HStack(alignment: .top) {
                        Text(round.displayTitle)
                            .font(AppTypography.headlineSmall)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        spotsBadge
                    }

                    // Invited by
                    if let inviter = inviterName {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                            Text("Invited by \(inviter)")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.primary)
                        }
                    }

                    // Location + Date
                    VStack(alignment: .leading, spacing: 4) {
                        if let location = round.displayLocationString {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin")
                                    .font(.caption)
                                    .foregroundColor(AppColors.iconAccent)
                                Text(location)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textPrimary.opacity(0.8))
                            }
                        }

                        if let dateText = round.displayDateTime {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(AppColors.iconAccent)
                                Text(dateText)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textPrimary.opacity(0.8))
                            }
                        }
                    }

                    // Price
                    Text(priceDisplay)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Action buttons (non-tappable area)
            HStack(spacing: AppSpacing.md) {
                SecondaryButton("Decline", icon: "xmark") {
                    onDecline()
                }

                PrimaryButton("Accept", icon: "checkmark") {
                    onAccept()
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppSpacing.radiusMedium)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var spotsBadge: some View {
        let remaining = round.spotsRemaining
        let color: Color = remaining > 0 ? AppColors.success : AppColors.textSecondary

        return Text("\(remaining) open")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(AppSpacing.radiusSmall)
    }

    private var priceDisplay: String {
        if let amount = round.price?.amount, amount > 0 {
            return "$\(amount)"
        }
        return "Price TBD"
    }
}
