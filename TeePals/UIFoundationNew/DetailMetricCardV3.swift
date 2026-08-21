import SwiftUI

/// Detail Metric Card V3 - Icon in rounded square, label, value
/// Used for Round Details grid (Group Size, Green Fee, Visibility)
struct DetailMetricCardV3: View {

    let icon: String
    let label: String
    let value: String

    init(icon: String, label: String, value: String) {
        self.icon = icon
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColorsV3.forestGreen.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppColorsV3.forestGreen)
                )

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.15 * 11)
                .foregroundColor(AppColorsV3.textSecondary)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColorsV3.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 12) {
        DetailMetricCardV3(icon: "person.2.fill", label: "Group Size", value: "4 Players")
        DetailMetricCardV3(icon: "dollarsign.circle", label: "Green Fee", value: "$75 / player")
    }
    .padding()
    .background(AppColorsV3.bgNeutral)
}
#endif
