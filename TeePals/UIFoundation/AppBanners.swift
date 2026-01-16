import SwiftUI

// MARK: - Inline Error Banner

/// Inline error banner for displaying errors within content flow.
struct InlineErrorBanner: View {
    
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        _ message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.error)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.error.opacity(0.1))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Warning Banner

/// Inline warning banner for displaying warnings within content flow.
struct InlineWarningBanner: View {
    
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        _ message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Info Banner

/// Inline info banner for displaying informational messages.
struct InlineInfoBanner: View {
    
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        _ message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.info)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.info)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.info.opacity(0.1))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.info.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Success Banner

/// Inline success banner for displaying success messages.
struct InlineSuccessBanner: View {
    
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        _ message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.success)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.success.opacity(0.1))
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Dismissable Banner Wrapper

/// Wrapper to make any banner dismissable.
struct DismissableBanner<Content: View>: View {
    
    @Binding var isVisible: Bool
    let content: () -> Content
    
    var body: some View {
        if isVisible {
            HStack(alignment: .top) {
                content()
                
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(AppSpacing.xs)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppBanners_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                InlineErrorBanner(
                    "Something went wrong. Please try again.",
                    actionTitle: "Retry",
                    action: {}
                )
                
                InlineWarningBanner(
                    "Your profile is incomplete. Complete it to join rounds.",
                    actionTitle: "Complete Profile",
                    action: {}
                )
                
                InlineInfoBanner(
                    "Rounds are automatically removed 24 hours after tee time."
                )
                
                InlineSuccessBanner(
                    "You've successfully joined the round!",
                    actionTitle: "View Round",
                    action: {}
                )
            }
            .padding()
        }
    }
}
#endif

