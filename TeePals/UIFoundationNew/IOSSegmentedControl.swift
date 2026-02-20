import SwiftUI

/// iOS-style segmented control with gray background and white active pill
/// Matches the V3 design system from RoundsList.html
struct IOSSegmentedControl<T: Hashable>: View {
    let items: [T]
    let itemTitle: (T) -> String
    @Binding var selection: T

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                } label: {
                    Text(itemTitle(item))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == item ? AppColorsV3.forestGreen : AppColorsV3.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selection == item {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "pill", in: animation)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(hex: "F1F1F1"))
        .cornerRadius(9)
    }
}

// MARK: - Preview

#if DEBUG
struct IOSSegmentedControl_Previews: PreviewProvider {
    enum TestSegment: String, CaseIterable {
        case nearby = "Nearby"
        case activity = "My Activity"
    }

    static var previews: some View {
        VStack(spacing: 20) {
            IOSSegmentedControl(
                items: TestSegment.allCases,
                itemTitle: { $0.rawValue },
                selection: .constant(.nearby)
            )
            .padding()

            IOSSegmentedControl(
                items: TestSegment.allCases,
                itemTitle: { $0.rawValue },
                selection: .constant(.activity)
            )
            .padding()
        }
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
