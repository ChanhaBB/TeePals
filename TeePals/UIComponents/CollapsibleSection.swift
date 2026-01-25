import SwiftUI

/// Collapsible section header for Activity view.
struct CollapsibleSection<Content: View>: View {
    let section: ActivitySection
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                onToggle()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    // Icon
                    Image(systemName: section.icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)

                    // Title
                    Text(section.title)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    // Count badge
                    if count > 0 {
                        Text("\(count)")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusSmall)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.backgroundGrouped)
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded && count > 0 {
                VStack(spacing: AppSpacing.md) {
                    content()
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.top, AppSpacing.sm)
            }
        }
    }

    private var iconColor: Color {
        switch section {
        case .actionRequired: return AppColors.error
        case .upcoming: return AppColors.primary
        case .pendingApproval: return AppColors.warning
        case .past: return AppColors.textSecondary
        }
    }
}
