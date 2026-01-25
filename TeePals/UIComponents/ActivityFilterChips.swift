import SwiftUI

/// Inline filter chips for Activity view.
struct ActivityFilterChips: View {
    @Binding var selectedFilter: ActivityFilter

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(ActivityFilter.allCases) { filter in
                filterChip(for: filter)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundGrouped)
    }

    private func filterChip(for filter: ActivityFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            Text(filter.title)
                .font(AppTypography.labelMedium)
                .foregroundColor(selectedFilter == filter ? .white : AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(selectedFilter == filter ? AppColors.primary : AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusFull)
        }
        .buttonStyle(.plain)
    }
}
