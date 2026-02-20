import SwiftUI

/// Primary button component for V3 design system
/// Features: Forest green background, rounded-full shape, uppercase text with tracking
struct PrimaryButtonV3: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .textCase(.uppercase)
                        .tracking(0.15 * 13) // 0.15em tracking
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                isDisabled
                    ? Color.gray.opacity(0.3)
                    : AppColorsV3.forestGreen
            )
            .cornerRadius(24) // rounded-full = half of height
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
            PrimaryButtonV3(title: "Continue", action: {})

            PrimaryButtonV3(title: "Continue", action: {}, isDisabled: true)

            PrimaryButtonV3(title: "Continue", action: {}, isLoading: true)

            PrimaryButtonV3(title: "Complete Setup", action: {})
        }
        .padding()
    }
}
#endif
