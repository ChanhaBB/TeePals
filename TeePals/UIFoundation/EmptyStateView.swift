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
        VStack(spacing: AppSpacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(AppColors.primary.opacity(0.4))
            
            // Text content
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Optional CTA
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, size: .medium, action: action)
                    .frame(maxWidth: 200)
                    .padding(.top, AppSpacing.sm)
            }
        }
        .padding(AppSpacing.xl)
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
        VStack(spacing: AppSpacing.xl) {
            EmptyStateView.noRounds(onCreate: {})
        }
        .background(AppColors.backgroundGrouped)
    }
}
#endif

