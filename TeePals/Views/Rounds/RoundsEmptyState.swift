import SwiftUI

/// Filter-aware empty state for rounds list.
/// Shows when no rounds match the current filters.
struct RoundsEmptyState: View {
    let onEditFilters: () -> Void
    let onCreateRound: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xxl)
                
                // Icon
                Image(systemName: "figure.golf")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.primary.opacity(0.4))
                
                // Text content
                VStack(spacing: AppSpacing.sm) {
                    Text("No rounds match your filters")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Try expanding distance or date range, or switch to Anywhere.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Action buttons
                VStack(spacing: AppSpacing.md) {
                    // Edit filters (secondary)
                    Button {
                        onEditFilters()
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Edit Filters")
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.primary)
                    }
                    
                    // Create round (primary)
                    PrimaryButton("Create Round", icon: "plus", size: .medium) {
                        onCreateRound()
                    }
                    .frame(maxWidth: 200)
                }
                .padding(.top, AppSpacing.sm)
                
                Spacer()
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Activity Empty State

struct ActivityEmptyState: View {
    let onCreateRound: () -> Void
    let onBrowseNearby: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.xxl)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.primary.opacity(0.4))

                VStack(spacing: AppSpacing.sm) {
                    Text("No Activity Yet")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Rounds you host or request will appear here.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppSpacing.md) {
                    PrimaryButton("Create Round", icon: "plus") {
                        onCreateRound()
                    }
                    .frame(maxWidth: 200)

                    Button("Browse Nearby") {
                        onBrowseNearby()
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
                }

                Spacer()
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct RoundsEmptyState_Previews: PreviewProvider {
    static var previews: some View {
        RoundsEmptyState(
            onEditFilters: {},
            onCreateRound: {}
        )
        .background(AppColors.backgroundGrouped)
    }
}
#endif

