import SwiftUI

/// Filter sheet for rounds list — V3 bottom sheet design.
struct RoundsFilterSheet: View {

    @ObservedObject var viewModel: RoundsListViewModel
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss

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
        VStack(spacing: 0) {
            sheetHeader
            sheetContent
        }
        .background(AppColorsV3.surfaceWhite)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button("Reset") { resetToDefaults() }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColorsV3.textSecondary)

            Spacer()

            Button("Apply") { applyFilters() }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColorsV3.forestGreen)
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.vertical, 20)
        .overlay(
            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Content

    private var sheetContent: some View {
        ScrollView {
            VStack(spacing: AppSpacingV3.lg) {
                FilterHostedBySection(selectedHostedBy: $selectedHostedBy)
                sectionDivider
                searchAreaSection
                sectionDivider
                FilterDateRangeSection(
                    selectedDateRange: $selectedDateRange,
                    showCustomDatePicker: $showCustomDatePicker,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate
                )
                sectionDivider
                FilterSortSection(selectedSort: $selectedSort, isAnywhereMode: isAnywhereMode)
            }
            .padding(AppSpacingV3.contentPadding)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColorsV3.borderLight)
            .frame(height: 1)
    }

    // MARK: - Search Area

    private var searchAreaSection: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            filterSectionHeader("Search Area")
            locationRow
            FilterDistanceChips(selectedDistance: $selectedDistance)
            helperText
        }
    }

    private var locationRow: some View {
        Button {
            if !isAnywhereMode { showCitySearch = true }
        } label: {
            HStack(spacing: AppSpacingV3.xs) {
                Image(systemName: "location.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isAnywhereMode ? AppColorsV3.textSecondary : AppColorsV3.forestGreen)

                Text(displayCityLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isAnywhereMode ? AppColorsV3.textSecondary : AppColorsV3.textPrimary)

                Spacer()

                if isAnywhereMode {
                    Text("Not used")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(6)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColorsV3.textSecondary)
                }
            }
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

    @ViewBuilder
    private var helperText: some View {
        if isAnywhereMode {
            helperPill {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                    Text("Shows rounds anywhere. Location is ignored.")
                }
            }
        } else if let radius = selectedDistance.intValue {
            helperPill {
                Text("Searching within ")
                    .foregroundColor(AppColorsV3.textSecondary)
                + Text("\(radius) miles")
                    .foregroundColor(AppColorsV3.forestGreen)
                    .font(.system(size: 11, weight: .bold))
                + Text(" of \(displayCityLabel)")
                    .foregroundColor(AppColorsV3.textSecondary)
            }
        }
    }

    private func helperPill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    // MARK: - Actions

    private func applyFilters() {
        let dateRange: DateRangeOption
        if showCustomDatePicker {
            dateRange = .custom(start: customStartDate, end: customEndDate)
        } else {
            dateRange = selectedDateRange
        }

        var finalSort = selectedSort
        if selectedDistance == .anywhere && selectedSort == .distance {
            finalSort = .date
        }

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

        Task { await viewModel.refresh() }
        dismiss()
    }

    private func resetToDefaults() {
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

// MARK: - Shared Section Header

func filterSectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 10, weight: .bold))
        .tracking(0.15 * 10)
        .textCase(.uppercase)
        .foregroundColor(AppColorsV3.textSecondary)
}
