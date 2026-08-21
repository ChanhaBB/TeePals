import SwiftUI

// MARK: - Hosted By Section

struct FilterHostedBySection: View {
    @Binding var selectedHostedBy: HostedByOption

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            SectionLabelV3(title: "Hosted By")
            SelectionChipRowV3(
                options: HostedByOption.allCases,
                selection: selectedHostedBy,
                labelProvider: { $0.displayText },
                onSelect: { selectedHostedBy = $0 }
            )
        }
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
            SectionLabelV3(title: "Date Range")

            SelectionChipGrid2V3(
                options: DateRangeOption.allPresets,
                selection: selectedDateRange,
                labelProvider: { $0.displayText },
                onSelect: { option in
                    selectedDateRange = option
                    showCustomDatePicker = false
                }
            )

            if showCustomDatePicker {
                customDatePickers
            }
        }
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
            SectionLabelV3(title: "Sort By")
            SelectionChipStackV3(
                options: sortOptions,
                selection: selectedSort,
                labelProvider: { $0.displayText },
                onSelect: { selectedSort = $0 }
            )
        }
    }
}

// MARK: - Distance Chips

struct FilterDistanceChips: View {
    @Binding var selectedDistance: DistanceSelection

    var body: some View {
        SelectionChipGrid3V3(
            options: DistanceSelection.allOptions,
            selection: selectedDistance,
            labelProvider: { $0.displayText },
            onSelect: { option in
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDistance = option
                }
            },
            compact: true
        )
    }
}
