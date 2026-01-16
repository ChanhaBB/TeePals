import SwiftUI

// MARK: - Course Section (with Search)

struct EditRoundCourseSection: View {
    @ObservedObject var viewModel: EditRoundViewModel
    @ObservedObject var searchService: GolfCourseSearchService
    @State private var searchQuery = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("COURSE")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(spacing: AppSpacing.md) {
                    if viewModel.isManualEntry {
                        manualEntryFields
                    } else {
                        searchFields
                    }
                    
                    // Toggle between search and manual
                    Button {
                        if viewModel.isManualEntry {
                            viewModel.isManualEntry = false
                        } else {
                            viewModel.switchToManualEntry()
                        }
                    } label: {
                        Text(viewModel.isManualEntry ? "Search for course instead" : "Enter manually instead")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }
    
    private var searchFields: some View {
        VStack(spacing: AppSpacing.md) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                TextField("Search golf courses...", text: $searchQuery)
                    .font(AppTypography.bodyMedium)
                    .onChange(of: searchQuery) { _, newValue in
                        searchService.search(query: newValue)
                    }
                
                if searchService.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            
            // Selected course display
            if let course = viewModel.selectedCourse {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text(course.cityLabel)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(AppColors.success.opacity(0.1))
                .cornerRadius(AppSpacing.radiusSmall)
            }
            
            // Search results
            if !searchService.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchService.searchResults) { result in
                        Button {
                            viewModel.selectCourse(result)
                            searchQuery = ""
                            searchService.clearResults()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(result.cityLabel)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, AppSpacing.sm)
                        }
                        
                        if result.id != searchService.searchResults.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private var manualEntryFields: some View {
        VStack(spacing: AppSpacing.md) {
            AppTextField(label: "Course Name", text: $viewModel.manualCourseName)
            AppTextField(label: "City", text: $viewModel.manualCityLabel)
        }
    }
}

// MARK: - Date Section

struct EditRoundDateSection: View {
    @Binding var preferredDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("DATE & TIME")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                DatePicker(
                    "Preferred Date & Time",
                    selection: $preferredDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }
}

// MARK: - Visibility Section

struct EditRoundVisibilitySection: View {
    @Binding var visibility: RoundVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("VISIBILITY")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(spacing: AppSpacing.md) {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(RoundVisibility.allCases, id: \.self) { option in
                            Text(option.displayText).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Show what join policy will be
                    HStack {
                        Image(systemName: visibility == .public ? "hand.raised.fill" : "bolt.fill")
                            .foregroundColor(AppColors.primary)
                        Text(visibility == .public ? "Players will request to join" : "Friends can join instantly")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}
