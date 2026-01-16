import SwiftUI

/// A selectable chip button for filter/option selection.
struct SelectableChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(AppTypography.bodyMedium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.primary : AppColors.backgroundSecondary)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .cornerRadius(AppRadii.chip)
        }
    }
}

/// A group of selectable chips.
struct ChipGroup<T: Hashable>: View {
    let options: [T]
    let selection: Set<T>
    let labelProvider: (T) -> String
    let onToggle: (T) -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(Array(options), id: \.self) { option in
                SelectableChip(
                    title: labelProvider(option),
                    isSelected: selection.contains(option)
                ) {
                    onToggle(option)
                }
            }
        }
    }
}

/// A single-selection chip group.
struct SingleSelectChipGroup<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let labelProvider: (T) -> String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(Array(options), id: \.self) { option in
                SelectableChip(
                    title: labelProvider(option),
                    isSelected: selection == option
                ) {
                    selection = option
                }
            }
        }
    }
}

