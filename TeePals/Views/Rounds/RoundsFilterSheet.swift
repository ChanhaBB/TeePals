import SwiftUI

/// Filter sheet for rounds list - allows users to customize search parameters.
struct RoundsFilterSheet: View {
    
    @ObservedObject var viewModel: RoundsListViewModel
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss
    
    // Local state for editing (applied on "Apply")
    @State private var selectedCityLabel: String?
    @State private var selectedCityLat: Double?
    @State private var selectedCityLng: Double?
    @State private var selectedDistance: DistanceSelection
    @State private var selectedDateRange: DateRangeOption
    @State private var selectedSort: RoundSortOption
    @State private var selectedHostedBy: HostedByOption
    @State private var customStartDate: Date
    @State private var customEndDate: Date
    @State private var showCustomDatePicker = false
    @State private var showCitySearch = false

    init(viewModel: RoundsListViewModel) {
        self.viewModel = viewModel
        _selectedCityLabel = State(initialValue: viewModel.filters.cityLabel)
        _selectedCityLat = State(initialValue: viewModel.filters.centerLat)
        _selectedCityLng = State(initialValue: viewModel.filters.centerLng)
        _selectedDistance = State(initialValue: viewModel.filters.distance)
        _selectedDateRange = State(initialValue: viewModel.filters.dateRange)
        _selectedSort = State(initialValue: viewModel.filters.sortBy)
        _selectedHostedBy = State(initialValue: viewModel.filters.hostedBy)
        _customStartDate = State(initialValue: Date())
        _customEndDate = State(initialValue: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    }
    
    private var isAnywhereMode: Bool {
        selectedDistance == .anywhere
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    hostedBySection
                    searchAreaSection
                    dateRangeSection
                    sortSection
                }
                .padding(AppSpacing.contentPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.backgroundGrouped.ignoresSafeArea())
            .navigationTitle("Filter Rounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Hosted By Section

    private var hostedBySection: some View {
        FilterHostedBySection(selectedHostedBy: $selectedHostedBy)
    }

    // MARK: - Search Area Section (Location + Distance coupled)
    
    private var searchAreaSection: some View {
        SectionCard(title: "Search Area") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Location row
                locationRow
                
                // Distance chips
                distanceChips
                
                // Helper text based on mode
                helperText
            }
        }
    }
    
    private var locationRow: some View {
        Button {
            if !isAnywhereMode {
                showCitySearch = true
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "location.fill")
                    .foregroundColor(isAnywhereMode ? AppColors.textSecondary : AppColors.iconAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayCityLabel)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(isAnywhereMode ? AppColors.textSecondary : AppColors.textPrimary)
                }
                
                Spacer()
                
                // "Not used" pill when Anywhere, else show chevron
                if isAnywhereMode {
                    Text("Not used")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusSmall)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.sm)
            .background(isAnywhereMode ? Color.clear : AppColors.primary.opacity(0.08))
            .cornerRadius(AppSpacing.radiusMedium)
            .opacity(isAnywhereMode ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isAnywhereMode)
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet(locationService: locationService) { cityLabel, coordinate in
                selectedCityLabel = cityLabel
                selectedCityLat = coordinate.latitude
                selectedCityLng = coordinate.longitude
            }
        }
    }
    
    private var displayCityLabel: String {
        if let cityLabel = selectedCityLabel, !cityLabel.isEmpty {
            return cityLabel
        } else if let profile = viewModel.userProfile {
            return profile.primaryCityLabel
        } else {
            return "Select location"
        }
    }
    
    private var distanceChips: some View {
        FilterDistanceChips(selectedDistance: $selectedDistance)
    }
    
    private var helperText: some View {
        Group {
            if isAnywhereMode {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                    Text("Shows rounds anywhere. Location is ignored.")
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            } else if let radius = selectedDistance.intValue {
                Text("Searching within \(radius) miles of \(displayCityLabel)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("Tap to change location")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        FilterDateRangeSection(
            selectedDateRange: $selectedDateRange,
            showCustomDatePicker: $showCustomDatePicker,
            customStartDate: $customStartDate,
            customEndDate: $customEndDate
        )
    }
    
    // MARK: - Sort Section
    
    private var sortSection: some View {
        FilterSortSection(selectedSort: $selectedSort, isAnywhereMode: isAnywhereMode)
    }
    
    // MARK: - Actions
    
    private func applyFilters() {
        // Handle custom date range
        let dateRange: DateRangeOption
        if showCustomDatePicker {
            dateRange = .custom(start: customStartDate, end: customEndDate)
        } else {
            dateRange = selectedDateRange
        }
        
        // If switching to anywhere and sort was distance, reset to date
        var finalSort = selectedSort
        if selectedDistance == .anywhere && selectedSort == .distance {
            finalSort = .date
        }
        
        // Apply city if user selected one, otherwise use profile city
        let cityLat = selectedCityLat ?? viewModel.userProfile?.primaryLocation.latitude
        let cityLng = selectedCityLng ?? viewModel.userProfile?.primaryLocation.longitude
        let cityLabel = selectedCityLabel ?? viewModel.userProfile?.primaryCityLabel
        
        viewModel.updateFilters(
            centerLat: cityLat,
            centerLng: cityLng,
            cityLabel: cityLabel,
            distance: selectedDistance,
            dateRange: dateRange,
            sortBy: finalSort,
            hostedBy: selectedHostedBy
        )

        // Reload rounds with new filters
        Task {
            await viewModel.refresh()
        }

        dismiss()
    }

    private func resetToDefaults() {
        // Only reset local UI state (user must tap Apply to actually load)
        selectedCityLabel = viewModel.userProfile?.primaryCityLabel
        selectedCityLat = viewModel.userProfile?.primaryLocation.latitude
        selectedCityLng = viewModel.userProfile?.primaryLocation.longitude
        selectedDistance = RoundsListFilters.defaultDistance
        selectedDateRange = RoundsListFilters.defaultDateRange
        selectedSort = .date
        selectedHostedBy = .everyone
        showCustomDatePicker = false
    }
}

