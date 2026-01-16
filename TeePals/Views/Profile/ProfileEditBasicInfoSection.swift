import SwiftUI

/// Basic Info section for ProfileEditView.
/// Contains: Nickname, Birthdate, Gender, Location, Occupation, Bio, Skill Level, Photos
struct ProfileEditBasicInfoSection: View {
    @ObservedObject var viewModel: ProfileEditViewModel
    @StateObject private var locationService = LocationService()
    
    @Binding var showingCitySearch: Bool
    @State private var isLocatingGPS = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case nickname, occupation, bio
    }
    
    var body: some View {
        Section {
            photosSection
            nicknameField
            birthdateField
            genderPicker
            locationField
            occupationField
            bioField
            skillLevelPicker
        } header: {
            Text("Basic Info")
        }
    }
    
    // MARK: - Nickname
    
    private var nicknameField: some View {
        FormFieldRow(icon: "person.fill") {
            HStack {
                TextField("Nickname", text: $viewModel.nickname)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .nickname)
                
                if focusedField == .nickname {
                    Button { focusedField = nil } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: focusedField)
        }
    }
    
    // MARK: - Birthdate
    
    private var birthdateField: some View {
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
    
    // MARK: - Gender
    
    private var genderPicker: some View {
        FormFieldRow(icon: "person.2.fill") {
            Picker("Gender", selection: $viewModel.gender) {
                Text("Select").tag(Gender?.none)
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.displayText).tag(Gender?.some(gender))
                }
            }
        }
    }
    
    // MARK: - Location
    
    private var locationField: some View {
        LocationFieldView(
            cityLabel: viewModel.primaryCityLabel,
            isLocating: $isLocatingGPS,
            onUseGPS: { useCurrentLocation() },
            onSearch: { showingCitySearch = true }
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
    
    // MARK: - Occupation
    
    private var occupationField: some View {
        FormFieldRow(icon: "briefcase.fill") {
            HStack {
                TextField("Occupation (optional)", text: $viewModel.occupation)
                    .textContentType(.jobTitle)
                    .focused($focusedField, equals: .occupation)
                
                if focusedField == .occupation {
                    Button { focusedField = nil } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: focusedField)
        }
    }
    
    // MARK: - Bio
    
    private var bioField: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: "text.quote")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                    .padding(.top, 8)
                TextField("Short bio (optional)", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .bio)
            }
            
            if focusedField == .bio {
                Button { focusedField = nil } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16))
                        Text("Done")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: focusedField)
    }
    
    // MARK: - Skill Level (Optional)
    
    private var skillLevelPicker: some View {
        FormFieldRow(icon: "chart.bar.fill") {
            Picker("Skill Level", selection: $viewModel.skillLevel) {
                Text("Not set").tag(SkillLevel?.none)
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.displayText).tag(SkillLevel?.some(level))
                }
            }
        }
    }
    
    // MARK: - Photos
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                Text("Photos")
                Spacer()
                Text("\(viewModel.photoUrls.count)/\(ProfileEditViewModel.maxPhotos)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            ProfilePhotoGrid(
                photoUrls: $viewModel.photoUrls,
                isUploading: viewModel.isUploadingPhoto,
                canAddMore: viewModel.canAddMorePhotos,
                onAddPhoto: { image in
                    Task { await viewModel.uploadPhoto(image) }
                },
                onDeletePhoto: { index in
                    Task { await viewModel.deletePhoto(at: index) }
                },
                onReorder: { source, destination in
                    viewModel.reorderPhotos(from: source, to: destination)
                }
            )
        }
    }
}

