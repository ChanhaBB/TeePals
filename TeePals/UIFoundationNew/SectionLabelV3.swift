import SwiftUI

/// Uppercase section label for filter sheets, form sections, and review cards.
/// Small, bold, tracked text in secondary color.
///
/// Use above chip groups, form fields, or card sections.
struct SectionLabelV3: View {
    let title: String
    var size: CGFloat = 10

    var body: some View {
        Text(title)
            .font(.system(size: size, weight: .bold))
            .tracking(0.15 * size)
            .textCase(.uppercase)
            .foregroundColor(AppColorsV3.textSecondary)
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionLabelV3(title: "Hosted By")
        SectionLabelV3(title: "Date Range")
        SectionLabelV3(title: "Preferred TeePals", size: 11)
    }
    .padding()
}
#endif
