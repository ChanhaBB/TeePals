import SwiftUI

/// Reusable empty state view with icon, title, message, and optional CTA.
struct EmptyStateView: View {
    
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: AppSpacingV3.md) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(AppColorsV3.forestGreen.opacity(0.4))
            
            VStack(spacing: AppSpacingV3.xs) {
                Text(title)
                    .font(AppTypographyV3.headlineLarge)
                    .foregroundColor(AppColorsV3.textPrimary)
                
                Text(message)
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButtonV3(actionTitle, size: .medium, action: action)
                    .frame(maxWidth: 200)
                    .padding(.top, AppSpacingV3.xs)
            }
        }
        .padding(AppSpacingV3.lg)
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Common Empty States

extension EmptyStateView {
    
    /// Empty state for no rounds
    static func noRounds(onCreate: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "figure.golf",
            title: "No Rounds Nearby",
            message: "Be the first to create a round in your area, or check back later.",
            actionTitle: "Create Round",
            action: onCreate
        )
    }
    
    /// Empty state for no notifications
    static var noNotifications: EmptyStateView {
        EmptyStateView(
            icon: "bell.slash",
            title: "All Caught Up",
            message: "You have no new notifications. Activity from rounds and connections will appear here."
        )
    }
    
    /// Empty state for empty feed
    static func emptyFeed(onExplore: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "newspaper",
            title: "Your Feed is Empty",
            message: "Follow golfers and join rounds to see activity here.",
            actionTitle: "Explore Rounds",
            action: onExplore
        )
    }
    
    /// Empty state for no search results
    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "Try adjusting your search or filters."
        )
    }
    
    /// Empty state for no profile
    static func noProfile(onSetup: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "No Profile Yet",
            message: "Set up your profile to connect with other golfers.",
            actionTitle: "Set Up Profile",
            action: onSetup
        )
    }
}

// MARK: - Preview

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacingV3.lg) {
            EmptyStateView.noRounds(onCreate: {})
        }
        .background(AppColorsV3.surfaceLight)
    }
}
#endif

