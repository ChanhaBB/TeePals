import SwiftUI

// MARK: - Date Range Section

struct FilterDateRangeSection: View {
    @Binding var selectedDateRange: DateRangeOption
    @Binding var showCustomDatePicker: Bool
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    var body: some View {
        SectionCard(title: "Date Range") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.sm) {
                    ForEach(DateRangeOption.allPresets, id: \.displayText) { option in
                        dateRangeChip(option)
                    }
                }
                
                if showCustomDatePicker {
                    customDatePickers
                }
            }
        }
    }
    
    private func dateRangeChip(_ option: DateRangeOption) -> some View {
        let isSelected = selectedDateRange == option
        
        return Button {
            selectedDateRange = option
            showCustomDatePicker = false
        } label: {
            Text(option.displayText)
                .font(AppTypography.labelMedium)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColors.primary : AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
    }
    
    private var customDatePickers: some View {
        VStack(spacing: AppSpacing.sm) {
            DatePicker(
                "From",
                selection: $customStartDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            
            DatePicker(
                "To",
                selection: $customEndDate,
                in: customStartDate...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
    }
}

// MARK: - Sort Section

struct FilterSortSection: View {
    @Binding var selectedSort: RoundSortOption
    let isAnywhereMode: Bool
    
    private var sortOptions: [RoundSortOption] {
        if isAnywhereMode {
            return [.date, .newest]
        } else {
            return RoundSortOption.allCases
        }
    }
    
    var body: some View {
        SectionCard(title: "Sort By") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(sortOptions, id: \.rawValue) { option in
                    sortRow(option)
                }
            }
        }
    }
    
    private func sortRow(_ option: RoundSortOption) -> some View {
        let isSelected = selectedSort == option
        
        return Button {
            selectedSort = option
        } label: {
            HStack {
                Text(option.displayText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                        .fontWeight(.semibold)
                }
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? AppColors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(AppSpacing.radiusMedium)
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
        ], spacing: AppSpacing.sm) {
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
                .font(AppTypography.labelMedium)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColors.primary : AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
    }
}

