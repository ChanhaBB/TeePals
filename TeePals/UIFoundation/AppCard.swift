import SwiftUI

/// Reusable card/surface component with consistent styling.
struct AppCard<Content: View>: View {
    
    let style: CardStyle
    let content: () -> Content
    
    init(
        style: CardStyle = .elevated,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(AppSpacing.cardPadding)
            .background(backgroundColor)
            .cornerRadius(AppSpacing.radiusLarge)
            .overlay(borderOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }
    
    // MARK: - Style Properties
    
    private var backgroundColor: Color {
        switch style {
        case .elevated, .interactive:
            return AppColors.surface
        case .flat:
            return AppColors.surfaceSecondary
        case .outlined:
            return AppColors.surface
        case .primary:
            return AppColors.primary
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        switch style {
        case .outlined:
            return AppColors.border
        default:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        style == .outlined ? 1 : 0
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated, .interactive:
            return .black.opacity(0.06)
        default:
            return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated:
            return 8
        case .interactive:
            return 4
        default:
            return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch style {
        case .elevated:
            return 2
        case .interactive:
            return 1
        default:
            return 0
        }
    }
}

// MARK: - Card Styles

enum CardStyle {
    /// Elevated with shadow (default)
    case elevated
    
    /// Flat background, no shadow
    case flat
    
    /// Outlined with border
    case outlined
    
    /// Interactive (smaller shadow, for tappable cards)
    case interactive
    
    /// Primary brand color background
    case primary
}

// MARK: - Tappable Card Variant

struct TappableCard<Content: View>: View {
    
    let action: () -> Void
    let content: () -> Content
    
    @State private var isPressed = false
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            content()
                .padding(AppSpacing.cardPadding)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.radiusLarge)
                .shadow(
                    color: .black.opacity(isPressed ? 0.02 : 0.06),
                    radius: isPressed ? 2 : 4,
                    y: isPressed ? 0 : 1
                )
                .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Pressable Button Style

private struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = pressed
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
struct AppCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                AppCard(style: .elevated) {
                    cardContent("Elevated Card")
                }
                
                AppCard(style: .flat) {
                    cardContent("Flat Card")
                }
                
                AppCard(style: .outlined) {
                    cardContent("Outlined Card")
                }
                
                AppCard(style: .primary) {
                    cardContent("Primary Card")
                        .foregroundColor(.white)
                }
                
                TappableCard(action: {}) {
                    cardContent("Tappable Card")
                }
            }
            .padding()
        }
        .background(AppColors.backgroundGrouped)
    }
    
    static func cardContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headlineSmall)
            Text("This is a sample card with some content.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

