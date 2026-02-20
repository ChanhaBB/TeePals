import SwiftUI

/// A chip for multi-select scenarios with clear selected/unselected states.
/// Selected: green fill + white text
/// Unselected: neutral background + primary text + border
struct MultiSelectChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppColors.primary : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A group of multi-select chips with selection summary.
struct MultiSelectChipGroup<T: Hashable>: View {
    let options: [T]
    let selection: Set<T>
    let labelProvider: (T) -> String
    let onToggle: (T) -> Void
    let allSelectedText: String
    let noneSelectedText: String
    
    init(
        options: [T],
        selection: Set<T>,
        labelProvider: @escaping (T) -> String,
        onToggle: @escaping (T) -> Void,
        allSelectedText: String = "All selected",
        noneSelectedText: String = "None selected"
    ) {
        self.options = options
        self.selection = selection
        self.labelProvider = labelProvider
        self.onToggle = onToggle
        self.allSelectedText = allSelectedText
        self.noneSelectedText = noneSelectedText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    MultiSelectChip(
                        title: labelProvider(option),
                        isSelected: selection.contains(option)
                    ) {
                        onToggle(option)
                    }
                }
            }
            
            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var summaryText: String {
        if selection.isEmpty {
            return noneSelectedText
        } else if selection.count == options.count {
            return allSelectedText
        } else {
            let names = options.filter { selection.contains($0) }.map { labelProvider($0) }
            return names.joined(separator: ", ") + " welcome"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MultiSelectChip(title: "Beginner", isSelected: true) {}
        MultiSelectChip(title: "Intermediate", isSelected: false) {}
    }
    .padding()
}

