import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var viewModel: ProfileSetupViewModel
    @StateObject private var locationService = LocationService()
    @EnvironmentObject private var authService: AuthService
    
    @State private var showingCitySearch = false
    @State private var isLocatingGPS = false
    
    init(viewModel: ProfileSetupViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                requiredSection
                aboutSection
                golfStatsSection
                saveSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Set Up Profile")
            .navigationBarTitleDisplayMode(.large)
            .disabled(viewModel.isLoading)
            .overlay { if viewModel.isLoading { loadingOverlay } }
            .alert("Error", isPresented: showingError, presenting: viewModel.errorMessage) { _ in
                Button("OK") { viewModel.errorMessage = nil }
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
            .task { await viewModel.loadExistingProfile() }
        }
    }
    
    // MARK: - Sections
    
    private var requiredSection: some View {
        Section {
            nicknameField
            birthDateField
            locationField
            genderPicker
        } header: {
            Text("Required")
        } footer: {
            Text("This information helps us match you with compatible golfers.")
        }
    }
    
    private var aboutSection: some View {
        Section("About You") {
            occupationField
            bioField
        }
    }
    
    private var golfStatsSection: some View {
        Section("Golf Stats (Optional)") {
            avgScoreField
            experienceYearsField
            playsPerMonthField
            skillLevelPicker
        }
    }
    
    private var saveSection: some View {
        Section {
            saveButton
        }
    }
    
    // MARK: - Required Fields
    
    private var nicknameField: some View {
        FormFieldRow(icon: "person.fill") {
            TextField("Nickname", text: $viewModel.nickname)
                .textContentType(.nickname)
                .autocorrectionDisabled()
        }
    }
    
    private var birthDateField: some View {
        FormFieldRow(icon: "calendar") {
            DatePicker(
                "Birth Date",
                selection: birthDateBinding,
                in: ...Date.now.addingTimeInterval(-18 * 365.25 * 24 * 60 * 60),
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
    
    private var locationField: some View {
        LocationFieldView(
            cityLabel: viewModel.primaryCityLabel,
            isLocating: $isLocatingGPS,
            onUseGPS: { useCurrentLocation() },
            onSearch: { showingCitySearch = true }
        )
    }
    
    private var genderPicker: some View {
        FormFieldRow(icon: "person.2.fill") {
            Picker("Gender", selection: $viewModel.gender) {
                Text("Select gender").tag(Gender?.none)
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.displayText).tag(Gender?.some(gender))
                }
            }
        }
    }
    
    // MARK: - About Fields
    
    private var occupationField: some View {
        FormFieldRow(icon: "briefcase.fill") {
            TextField("Occupation (optional)", text: $viewModel.occupation)
                .textContentType(.jobTitle)
        }
    }
    
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
        FormFieldRow(icon: "number") {
            Picker("Average Score (18 holes)", selection: $viewModel.avgScore) {
                Text("Not set").tag(Int?.none)
                ForEach(AvgScoreOption.allCases) { option in
                    Text(option.displayText).tag(Int?.some(option.rawValue))
                }
            }
        }
    }
    
    private var experienceYearsField: some View {
        FormFieldRow(icon: "clock.fill") {
            Picker("Experience", selection: $viewModel.experienceLevel) {
                Text("Not set").tag(ExperienceLevel?.none)
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    Text(level.displayText).tag(ExperienceLevel?.some(level))
                }
            }
        }
    }
    
    private var playsPerMonthField: some View {
        FormFieldRow(icon: "calendar.badge.clock") {
            TextField("Rounds per month", value: $viewModel.playsPerMonth, format: .number)
                .keyboardType(.numberPad)
        }
    }
    
    private var skillLevelPicker: some View {
        FormFieldRow(icon: "chart.bar.fill") {
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
                if success { authService.completeProfileSetup() }
            }
        } label: {
            HStack {
                Spacer()
                Text("Save & Continue").fontWeight(.semibold)
                Spacer()
            }
        }
        .disabled(!viewModel.canSave)
    }
    
    // MARK: - Helpers
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.2)
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(12)
        }
    }
    
    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
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
}
