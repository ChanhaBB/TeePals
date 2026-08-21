import SwiftUI
import UIKit

// MARK: - Button Size

enum ButtonSize {
    case large
    case medium
    case small
}

/// Primary button component for V3 design system
/// Features: Forest green background, rounded shape, uppercase text with tracking
struct PrimaryButtonV3: View {
    let title: String
    let icon: String?
    let size: ButtonSize
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .large,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.action = action
    }

    init(
        title: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        isLoading: Bool = false
    ) {
        self.title = title
        self.icon = nil
        self.size = .large
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.action = action
    }

    private var buttonHeight: CGFloat {
        switch size {
        case .large: return AppSpacingV3.buttonHeightLarge
        case .medium: return AppSpacingV3.buttonHeightMedium
        case .small: return AppSpacingV3.buttonHeightSmall
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .large: return 13
        case .medium: return 12
        case .small: return 11
        }
    }

    var body: some View {
        Button {
            guard !isLoading && !isDisabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    HStack(spacing: AppSpacingV3.iconSpacing) {
                        if let icon {
                            Image(systemName: icon)
                        }
                        Text(title)
                    }
                    .font(.system(size: fontSize, weight: .bold, design: .default))
                    .textCase(.uppercase)
                    .tracking(0.15 * fontSize)
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                isDisabled
                    ? AppColorsV3.textDisabled
                    : AppColorsV3.forestGreen
            )
            .cornerRadius(buttonHeight / 2)
            .shadow(
                color: isDisabled ? .clear : AppColorsV3.forestGreen.opacity(0.2),
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Button style that scales down on press
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct PrimaryButtonV3_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PrimaryButtonV3("Continue", action: {})

            PrimaryButtonV3("Continue", isDisabled: true, action: {})

            PrimaryButtonV3("Continue", isLoading: true, action: {})

            PrimaryButtonV3("Create Round", icon: "plus.circle.fill", size: .medium, action: {})

            PrimaryButtonV3("Small", size: .small, action: {})
        }
        .padding()
    }
}
#endif
