import SwiftUI

/// A selectable chip with V3 filter styling.
/// Selected: forest green fill + white text + subtle shadow.
/// Unselected: light gray background + secondary text + border.
///
/// Use for single-select options (Hosted By, Date Range, Sort, Distance, etc.)
struct SelectionChipV3: View {
    let title: String
    let isSelected: Bool
    var compact: Bool = false
    let action: () -> Void

    private var fontSize: CGFloat { compact ? 11 : 12 }
    private var verticalPadding: CGFloat { compact ? 10 : 12 }
    private var cornerRadius: CGFloat { compact ? 8 : AppSpacingV3.radiusButton }
    private var shadowRadius: CGFloat { compact ? 3 : 4 }
    private var shadowY: CGFloat { compact ? 1 : 2 }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .tracking(compact ? 0 : 0.3)
                .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .background(isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(cornerRadius)
                .shadow(
                    color: isSelected ? AppColorsV3.forestGreen.opacity(compact ? 0.15 : 0.2) : .clear,
                    radius: shadowRadius, y: shadowY
                )
        }
        .buttonStyle(.plain)
    }
}

/// A group of selection chips in a horizontal row (equal width).
struct SelectionChipRowV3<T: Hashable>: View {
    let options: [T]
    let selection: T
    let labelProvider: (T) -> String
    let onSelect: (T) -> Void
    var compact: Bool = false

    var body: some View {
        HStack(spacing: AppSpacingV3.sm) {
            ForEach(options, id: \.self) { option in
                SelectionChipV3(
                    title: labelProvider(option),
                    isSelected: selection == option,
                    compact: compact
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

/// A grid of selection chips (2 columns).
struct SelectionChipGrid2V3<T: Hashable>: View {
    let options: [T]
    let selection: T
    let labelProvider: (T) -> String
    let onSelect: (T) -> Void
    var compact: Bool = false

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacingV3.sm) {
            ForEach(options, id: \.self) { option in
                SelectionChipV3(
                    title: labelProvider(option),
                    isSelected: selection == option,
                    compact: compact
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

/// A grid of selection chips (3 columns).
struct SelectionChipGrid3V3<T: Hashable>: View {
    let options: [T]
    let selection: T
    let labelProvider: (T) -> String
    let onSelect: (T) -> Void
    var compact: Bool = false

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacingV3.sm) {
            ForEach(options, id: \.self) { option in
                SelectionChipV3(
                    title: labelProvider(option),
                    isSelected: selection == option,
                    compact: compact
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

/// A vertical stack of full-width selection chips.
struct SelectionChipStackV3<T: Hashable>: View {
    let options: [T]
    let selection: T
    let labelProvider: (T) -> String
    let onSelect: (T) -> Void
    var compact: Bool = false

    var body: some View {
        VStack(spacing: AppSpacingV3.sm) {
            ForEach(options, id: \.self) { option in
                SelectionChipV3(
                    title: labelProvider(option),
                    isSelected: selection == option,
                    compact: compact
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        SelectionChipRowV3(
            options: ["Everyone", "Following"],
            selection: "Everyone",
            labelProvider: { $0 },
            onSelect: { _ in }
        )

        SelectionChipGrid2V3(
            options: ["This Week", "Next 30 Days", "Custom"],
            selection: "This Week",
            labelProvider: { $0 },
            onSelect: { _ in }
        )

        SelectionChipStackV3(
            options: ["Date", "Distance", "Newest"],
            selection: "Date",
            labelProvider: { $0 },
            onSelect: { _ in }
        )
    }
    .padding()
}
#endif
