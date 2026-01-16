import SwiftUI

/// Pending feedback section for Profile tab.
/// Shows rounds that need feedback with urgency indicators.
struct PendingFeedbackSection: View {
    let pendingItems: [PendingFeedback]
    let onTap: (String) -> Void // roundId

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Section header
                Text("Pending Feedback")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Divider()

                if pendingItems.isEmpty {
                    // Empty state
                    Text("No feedback needed at this time")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.sm)
                } else {
                    // List of pending items (max 3 shown)
                    ForEach(Array(pendingItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        PendingFeedbackRow(
                            item: item,
                            onTap: { onTap(item.roundId) }
                        )

                        if index < min(2, pendingItems.count - 1) {
                            Divider()
                        }
                    }

                    // Show "View All" if more than 3
                    if pendingItems.count > 3 {
                        Button("View All (\(pendingItems.count - 3) more)") {
                            // Navigate to full list screen (future enhancement)
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.primary)
                        .padding(.top, AppSpacing.sm)
                    }
                }
            }
            .padding(AppSpacing.contentPadding)
        }
    }
}

// MARK: - Pending Feedback Row

private struct PendingFeedbackRow: View {
    let item: PendingFeedback
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Course icon
                Image(systemName: "figure.golf")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Circle())

                // Course & date info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.courseName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: AppSpacing.xs) {
                        Text(item.completedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.labelSmall)
                            .foregroundColor(AppColors.textSecondary)

                        Text("•")
                            .foregroundColor(AppColors.textTertiary)

                        Text(item.timeLeftText)
                            .font(AppTypography.labelSmall)
                            .foregroundColor(urgencyColor(for: item))
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func urgencyColor(for item: PendingFeedback) -> Color {
        let days = item.daysRemaining
        if days <= 1 {
            return AppColors.error
        } else if days <= 3 {
            return .orange
        } else {
            return AppColors.textSecondary
        }
    }
}
