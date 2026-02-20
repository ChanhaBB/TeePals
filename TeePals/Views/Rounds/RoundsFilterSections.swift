import SwiftUI

// MARK: - Hosted By Section

struct FilterHostedBySection: View {
    @Binding var selectedHostedBy: HostedByOption

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            filterSectionHeader("Hosted By")

            HStack(spacing: AppSpacingV3.sm) {
                filterChip(.everyone)
                filterChip(.following)
            }
        }
    }

    private func filterChip(_ option: HostedByOption) -> some View {
        let isSelected = selectedHostedBy == option

        return Button { selectedHostedBy = option } label: {
            Text(option.displayText)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(AppSpacingV3.radiusButton)
                .shadow(
                    color: isSelected ? AppColorsV3.forestGreen.opacity(0.2) : .clear,
                    radius: 4, y: 2
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Range Section

struct FilterDateRangeSection: View {
    @Binding var selectedDateRange: DateRangeOption
    @Binding var showCustomDatePicker: Bool
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            filterSectionHeader("Date Range")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacingV3.sm) {
                ForEach(DateRangeOption.allPresets, id: \.displayText) { option in
                    dateChip(option)
                }
            }

            if showCustomDatePicker {
                customDatePickers
            }
        }
    }

    private func dateChip(_ option: DateRangeOption) -> some View {
        let isSelected = selectedDateRange == option

        return Button {
            selectedDateRange = option
            showCustomDatePicker = false
        } label: {
            Text(option.displayText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(AppSpacingV3.radiusButton)
                .shadow(
                    color: isSelected ? AppColorsV3.forestGreen.opacity(0.2) : .clear,
                    radius: 4, y: 2
                )
        }
        .buttonStyle(.plain)
    }

    private var customDatePickers: some View {
        VStack(spacing: AppSpacingV3.xs) {
            DatePicker("From", selection: $customStartDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.compact)
            DatePicker("To", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                .datePickerStyle(.compact)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(AppSpacingV3.sm)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(AppSpacingV3.radiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Sort Section

struct FilterSortSection: View {
    @Binding var selectedSort: RoundSortOption
    let isAnywhereMode: Bool

    private var sortOptions: [RoundSortOption] {
        isAnywhereMode ? [.date, .newest] : RoundSortOption.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            filterSectionHeader("Sort By")

            VStack(spacing: AppSpacingV3.sm) {
                ForEach(sortOptions, id: \.rawValue) { option in
                    sortChip(option)
                }
            }
        }
    }

    private func sortChip(_ option: RoundSortOption) -> some View {
        let isSelected = selectedSort == option

        return Button { selectedSort = option } label: {
            Text(option.displayText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(AppSpacingV3.radiusButton)
                .shadow(
                    color: isSelected ? AppColorsV3.forestGreen.opacity(0.2) : .clear,
                    radius: 4, y: 2
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Distance Chips

struct FilterDistanceChips: View {
    @Binding var selectedDistance: DistanceSelection

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacingV3.sm) {
            ForEach(DistanceSelection.allOptions, id: \.self) { option in
                distanceChip(option)
            }
        }
    }

    private func distanceChip(_ option: DistanceSelection) -> some View {
        let isSelected = selectedDistance == option

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDistance = option
            }
        } label: {
            Text(option.displayText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(8)
                .shadow(
                    color: isSelected ? AppColorsV3.forestGreen.opacity(0.15) : .clear,
                    radius: 3, y: 1
                )
        }
        .buttonStyle(.plain)
    }
}
