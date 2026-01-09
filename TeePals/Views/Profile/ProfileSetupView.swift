import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var viewModel: ProfileSetupViewModel
    @StateObject private var locationService = LocationService()
    @EnvironmentObject private var authService: AuthService
    
    @State private var showingCitySearch = false
    @State private var showingBirthDatePicker = false
    @State private var isLocatingGPS = false
    
    init(viewModel: ProfileSetupViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Required Section
                Section {
                    nicknameField
                    birthDateField
                    locationField
                } header: {
                    Text("Required")
                } footer: {
                    Text("This information helps us match you with compatible golfers.")
                }
                
                // MARK: - About You Section
                Section("About You") {
                    genderPicker
                    occupationField
                    bioField
                }
                
                // MARK: - Golf Stats Section
                Section("Golf Stats (Optional)") {
                    avgScoreField
                    experienceYearsField
                    playsPerMonthField
                    skillLevelPicker
                }
                
                // MARK: - Save Button
                Section {
                    saveButton
                }
            }
            .navigationTitle("Set Up Profile")
            .navigationBarTitleDisplayMode(.large)
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .alert("Error", isPresented: showingError, presenting: viewModel.errorMessage) { _ in
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $showingCitySearch) {
                CitySearchSheet(
                    locationService: locationService,
                    onSelect: { cityLabel, coordinate in
                        viewModel.setLocation(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            cityLabel: cityLabel
                        )
                    }
                )
            }
            .task {
                await viewModel.loadExistingProfile()
            }
        }
    }
    
    // MARK: - Nickname Field
    
    private var nicknameField: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)
            TextField("Nickname", text: $viewModel.nickname)
                .textContentType(.nickname)
                .autocorrectionDisabled()
        }
    }
    
    // MARK: - Birth Date Field
    
    private var birthDateField: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            DatePicker(
                "Birth Date",
                selection: birthDateBinding,
                in: ...Date.now.addingTimeInterval(-18 * 365.25 * 24 * 60 * 60), // 18+ only
                displayedComponents: .date
            )
        }
    }
    
    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.birthDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date() },
            set: { viewModel.birthDate = $0 }
        )
    }
    
    // MARK: - Location Field
    
    private var locationField: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                if viewModel.primaryCityLabel.isEmpty {
                    Text("Set your home location")
                        .foregroundColor(.secondary)
                } else {
                    Text(viewModel.primaryCityLabel)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    useCurrentLocation()
                } label: {
                    HStack {
                        if isLocatingGPS {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.circle")
                        }
                        Text("Use GPS")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isLocatingGPS)
                
                Button {
                    showingCitySearch = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func useCurrentLocation() {
        isLocatingGPS = true
        Task {
            let result = await locationService.requestCurrentLocation()
            isLocatingGPS = false
            if let location = result.location, let cityLabel = result.cityLabel {
                viewModel.setLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cityLabel: cityLabel
                )
            }
        }
    }
    
    // MARK: - Gender Picker
    
    private var genderPicker: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Picker("Gender", selection: $viewModel.gender) {
                Text("Prefer not to say").tag(Gender?.none)
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.displayText).tag(Gender?.some(gender))
                }
            }
        }
    }
    
    // MARK: - Occupation Field
    
    private var occupationField: some View {
        HStack {
            Image(systemName: "briefcase.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)
            TextField("Occupation (optional)", text: $viewModel.occupation)
                .textContentType(.jobTitle)
        }
    }
    
    // MARK: - Bio Field
    
    private var bioField: some View {
        HStack(alignment: .top) {
            Image(systemName: "text.quote")
                .foregroundColor(.secondary)
                .frame(width: 24)
                .padding(.top, 8)
            TextField("Short bio (optional)", text: $viewModel.bio, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Golf Stats Fields
    
    private var avgScoreField: some View {
        HStack {
            Image(systemName: "number")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField("Average 18-hole score", value: $viewModel.avgScore18, format: .number)
                .keyboardType(.numberPad)
        }
    }
    
    private var experienceYearsField: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField("Years playing golf", value: $viewModel.experienceYears, format: .number)
                .keyboardType(.numberPad)
        }
    }
    
    private var playsPerMonthField: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField("Rounds per month", value: $viewModel.playsPerMonth, format: .number)
                .keyboardType(.numberPad)
        }
    }
    
    private var skillLevelPicker: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Picker("Skill Level", selection: $viewModel.skillLevel) {
                Text("Not specified").tag(SkillLevel?.none)
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.displayText).tag(SkillLevel?.some(level))
                }
            }
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            Task {
                let success = await viewModel.saveProfile()
                if success {
                    authService.completeProfileSetup()
                }
            }
        } label: {
            HStack {
                Spacer()
                Text("Save & Continue")
                    .fontWeight(.semibold)
                Spacer()
            }
        }
        .disabled(!viewModel.canSave)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.2)
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Error Binding
    
    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - City Search Sheet

struct CitySearchSheet: View {
    @ObservedObject var locationService: LocationService
    let onSelect: (String, CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a city...", text: $searchText)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, newValue in
                            locationService.searchCities(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            locationService.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                Divider()
                
                // Results
                if locationService.isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if locationService.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No cities found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(locationService.searchResults) { result in
                        Button {
                            onSelect(result.cityLabel, result.coordinate)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Import for CLLocationCoordinate2D
import CoreLocation
