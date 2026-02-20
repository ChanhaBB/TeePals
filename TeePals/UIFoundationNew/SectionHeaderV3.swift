import SwiftUI

/// Section Header V3 - Title with optional "View All" link
/// Used for "My Schedule", "Discover Rounds" sections
struct SectionHeaderV3: View {

    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(AppTypographyV3.sectionHeaderSerif)
                .foregroundColor(AppColorsV3.textPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypographyV3.labelLink)
                        .buttonUppercaseStyle(tracking: 0.15)
                        .foregroundColor(AppColorsV3.forestGreen)
                        .overlay(
                            Rectangle()
                                .fill(AppColorsV3.forestGreen.opacity(0.2))
                                .frame(height: 1)
                                .offset(y: 6)
                        )
                }
            }
        }
        .padding(.horizontal, 4) // px-1 in HTML
    }
}

// MARK: - Preview

#if DEBUG
struct SectionHeaderV3_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // With action
            SectionHeaderV3(
                title: "My Schedule",
                actionTitle: "View All",
                action: { print("View All tapped") }
            )

            // Without action
            SectionHeaderV3(title: "Discover Rounds")

            // Another with action
            SectionHeaderV3(
                title: "Discover Rounds",
                actionTitle: "View All",
                action: { print("Discover tapped") }
            )
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
