import SwiftUI
import UIKit

// MARK: - Primary Button

/// Primary action button with loading, disabled, and pressed states.
/// Includes haptic feedback per UI_RULES.md.
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let size: ButtonSize
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .large,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button {
            guard !isLoading && isEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            buttonContent
        }
        .buttonStyle(PrimaryButtonStyle(
            size: size,
            isLoading: isLoading,
            isEnabled: isEnabled
        ))
        .disabled(!isEnabled || isLoading)
    }
    
    private var buttonContent: some View {
        HStack(spacing: AppSpacing.iconSpacing) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
            } else if let icon = icon {
                Image(systemName: icon)
            }
            Text(isLoading ? "Loading..." : title)
        }
    }
}

// MARK: - Primary Button Style

private struct PrimaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isLoading: Bool
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(textFont)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.radiusMedium)
            .contentShape(Rectangle()) // Ensures entire button area is tappable
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled { return AppColors.textDisabled }
        return isPressed ? AppColors.primaryDark : AppColors.primary
    }
    
    private var buttonHeight: CGFloat {
        switch size {
        case .large: return AppSpacing.buttonHeightLarge
        case .medium: return AppSpacing.buttonHeightMedium
        case .small: return AppSpacing.buttonHeightSmall
        }
    }
    
    private var textFont: Font {
        switch size {
        case .large: return AppTypography.buttonLarge
        case .medium: return AppTypography.buttonMedium
        case .small: return AppTypography.buttonSmall
        }
    }
}

// MARK: - Secondary Button

/// Secondary action button with loading, disabled, and pressed states.
/// Includes haptic feedback per UI_RULES.md.
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let size: ButtonSize
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .large,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button {
            guard !isLoading && isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            buttonContent
        }
        .buttonStyle(SecondaryButtonStyle(
            size: size,
            isLoading: isLoading,
            isEnabled: isEnabled
        ))
        .disabled(!isEnabled || isLoading)
    }
    
    private var buttonContent: some View {
        HStack(spacing: AppSpacing.iconSpacing) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    .scaleEffect(0.9)
            } else if let icon = icon {
                Image(systemName: icon)
            }
            Text(isLoading ? "Loading..." : title)
        }
    }
}

// MARK: - Secondary Button Style

private struct SecondaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isLoading: Bool
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(textFont)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 1.5)
            )
            .contentShape(Rectangle()) // Ensures entire button area is tappable
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        isPressed ? AppColors.primaryLight : .clear
    }
    
    private var foregroundColor: Color {
        isEnabled ? AppColors.primary : AppColors.textDisabled
    }
    
    private func borderColor(isPressed: Bool) -> Color {
        if !isEnabled { return AppColors.textDisabled }
        return isPressed ? AppColors.primaryDark : AppColors.primary
    }
    
    private var buttonHeight: CGFloat {
        switch size {
        case .large: return AppSpacing.buttonHeightLarge
        case .medium: return AppSpacing.buttonHeightMedium
        case .small: return AppSpacing.buttonHeightSmall
        }
    }
    
    private var textFont: Font {
        switch size {
        case .large: return AppTypography.buttonLarge
        case .medium: return AppTypography.buttonMedium
        case .small: return AppTypography.buttonSmall
        }
    }
}

// MARK: - Button Size

enum ButtonSize {
    case large
    case medium
    case small
}

// MARK: - Text Button (Tertiary)

/// Tertiary text-only button with haptic feedback.
struct TextButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        color: Color = AppColors.primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(AppTypography.buttonMedium)
            .foregroundColor(color)
        }
        .buttonStyle(TextButtonStyle())
    }
}

private struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct AppButtons_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.lg) {
            Group {
                Text("Primary Buttons").font(AppTypography.labelMedium)
                PrimaryButton("Get Started", icon: "arrow.right") {}
                PrimaryButton("Loading...", isLoading: true) {}
                PrimaryButton("Disabled", isEnabled: false) {}
                PrimaryButton("Small", size: .small) {}
            }
            
            Divider()
            
            Group {
                Text("Secondary Buttons").font(AppTypography.labelMedium)
                SecondaryButton("Edit Profile", icon: "pencil") {}
                SecondaryButton("Loading...", isLoading: true) {}
                SecondaryButton("Disabled", isEnabled: false) {}
            }
            
            Divider()
            
            Group {
                Text("Text Buttons").font(AppTypography.labelMedium)
                TextButton("Skip for now") {}
                TextButton("Delete", icon: "trash", color: AppColors.error) {}
            }
        }
        .padding()
    }
}
#endif
