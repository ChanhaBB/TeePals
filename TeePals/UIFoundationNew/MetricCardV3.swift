import SwiftUI

/// Metric Card V3 - Displays a metric with icon and label
/// Used for Invites, Pending counts on home screen
struct MetricCardV3: View {

    let icon: String
    let count: Int
    let label: String
    let hasNotification: Bool
    let action: () -> Void

    init(
        icon: String,
        count: Int,
        label: String,
        hasNotification: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.count = count
        self.label = label
        self.hasNotification = hasNotification
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                // Left: Number and label
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(count)")
                        .font(AppTypographyV3.numberLargeSerif)
                        .foregroundColor(count > 0 ? AppColorsV3.forestGreen : AppColorsV3.textSecondary.opacity(0.5))

                    Text(label)
                        .labelUppercaseStyle(tracking: 0.2)
                        .foregroundColor(AppColorsV3.textSecondary)
                }

                Spacer()

                // Right: Icon with optional notification dot
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(count > 0 ? AppColorsV3.forestGreen.opacity(0.05) : Color.gray.opacity(0.05))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(count > 0 ? AppColorsV3.forestGreen : AppColorsV3.textSecondary.opacity(0.3))
                        )

                    if hasNotification && count > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .offset(x: 8, y: 8)
                    }
                }
            }
            .padding(AppSpacingV3.md + 4) // p-5 in HTML
            .frame(maxWidth: .infinity)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(AppSpacingV3.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                    .stroke(AppColorsV3.borderLight, lineWidth: 1)
            )
            .premiumShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct MetricCardV3_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                MetricCardV3(
                    icon: "envelope.fill",
                    count: 2,
                    label: "Invites",
                    hasNotification: true,
                    action: {}
                )

                MetricCardV3(
                    icon: "hourglass",
                    count: 1,
                    label: "Pending",
                    action: {}
                )
            }

            HStack(spacing: 16) {
                MetricCardV3(
                    icon: "envelope.fill",
                    count: 0,
                    label: "Invites",
                    action: {}
                )

                MetricCardV3(
                    icon: "hourglass",
                    count: 0,
                    label: "Pending",
                    action: {}
                )
            }
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
