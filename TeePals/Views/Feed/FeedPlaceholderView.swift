import SwiftUI

/// Temporary placeholder for the Feed tab shown during the initial App Store launch.
/// Swap this back to FeedView in MainTabView.swift when the feed is ready for release.
struct FeedPlaceholderView: View {

    var body: some View {
        ZStack {
            AppColorsV3.bgNeutral
                .ignoresSafeArea()

            VStack(spacing: AppSpacingV3.lg) {
                Image(systemName: "newspaper")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(AppColorsV3.forestGreen.opacity(0.4))

                VStack(spacing: AppSpacingV3.sm) {
                    Text("The Feed")
                        .font(AppTypographyV3.sectionHeaderSerif)
                        .foregroundColor(AppColorsV3.textPrimary)

                    Text("Post round recaps, share moments from the course, and tag your playing partners.")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("COMING SOON")
                    .font(AppTypographyV3.labelUppercaseBold)
                    .foregroundColor(AppColorsV3.forestGreen)
                    .padding(.horizontal, AppSpacingV3.md)
                    .padding(.vertical, AppSpacingV3.xs)
                    .background(AppColorsV3.forestGreen.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FeedPlaceholderView()
}
#endif
