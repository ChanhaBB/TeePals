import SwiftUI

/// Filter-aware empty state for rounds list.
/// Shows when no rounds match the current filters.
struct RoundsEmptyState: View {
    let onEditFilters: () -> Void
    let onCreateRound: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacingV3.md) {
                Spacer(minLength: AppSpacingV3.xl)
                
                Image(systemName: "figure.golf")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColorsV3.forestGreen.opacity(0.4))
                
                VStack(spacing: AppSpacingV3.xs) {
                    Text("No rounds match your filters")
                        .font(AppTypographyV3.headlineLarge)
                        .foregroundColor(AppColorsV3.textPrimary)
                    
                    Text("Try expanding distance or date range, or switch to Anywhere.")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(spacing: AppSpacingV3.sm) {
                    Button {
                        onEditFilters()
                    } label: {
                        HStack(spacing: AppSpacingV3.xxs) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Edit Filters")
                        }
                        .font(AppTypographyV3.labelMedium)
                        .foregroundColor(AppColorsV3.forestGreen)
                    }
                    
                    PrimaryButtonV3("Create Round", icon: "plus", size: .medium) {
                        onCreateRound()
                    }
                    .frame(maxWidth: 200)
                }
                .padding(.top, AppSpacingV3.xs)
                
                Spacer()
            }
            .padding(AppSpacingV3.lg)
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
            VStack(spacing: AppSpacingV3.lg) {
                Spacer(minLength: AppSpacingV3.xl)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColorsV3.forestGreen.opacity(0.4))

                VStack(spacing: AppSpacingV3.xs) {
                    Text("No Activity Yet")
                        .font(AppTypographyV3.headlineLarge)
                        .foregroundColor(AppColorsV3.textPrimary)

                    Text("Rounds you host or request will appear here.")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppSpacingV3.sm) {
                    PrimaryButtonV3("Create Round", icon: "plus") {
                        onCreateRound()
                    }
                    .frame(maxWidth: 200)

                    Button("Browse Nearby") {
                        onBrowseNearby()
                    }
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.forestGreen)
                }

                Spacer()
            }
            .padding(AppSpacingV3.lg)
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
        .background(AppColorsV3.surfaceLight)
    }
}
#endif
