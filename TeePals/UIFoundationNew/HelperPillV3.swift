import SwiftUI

/// A subtle pill for helper text, hints, or contextual info.
/// Light gray background with optional icon.
struct HelperPillV3<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AppColorsV3.textSecondary)
            .padding(AppSpacingV3.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
    }
}

extension HelperPillV3 where Content == Text {
    init(_ text: String) {
        self.content = { Text(text) }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        HelperPillV3("Shows rounds anywhere. Location is ignored.")

        HelperPillV3 {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                Text("Searching within 25 miles of San Diego")
            }
        }
    }
    .padding()
}
#endif
