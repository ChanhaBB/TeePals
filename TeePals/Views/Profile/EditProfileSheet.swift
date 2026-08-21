import SwiftUI
import PhotosUI

/// Unified "Edit Profile" full-screen cover — photo, bio, personal info, and golf profile in one place.
struct EditProfileSheet: View {
    @StateObject private var viewModel: ProfileEditViewModel
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss
    @State private var showingCitySearch = false
    @State private var showingGenderPicker = false
    @State private var showingBirthdatePicker = false
    @State private var showingSkillPicker = false
    @State private var showingPlaysPicker = false
    @State private var showingScorePicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    let onSave: () -> Void

    init(viewModel: ProfileEditViewModel, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader

            Divider()
                .foregroundColor(AppColorsV3.borderLight)

            ScrollView {
                VStack(spacing: 0) {
                    photoSection

                    formSectionLabel("Bio")
                    formCard { bioRow }

                    formSectionLabel("Personal Info")
                    formCard {
                        VStack(spacing: 0) {
                            editRow(
                                icon: "location.fill",
                                label: "City",
                                value: viewModel.primaryCityLabel.isEmpty ? "Select" : viewModel.primaryCityLabel
                            ) { showingCitySearch = true }

                            rowDivider

                            editRow(
                                icon: "birthday.cake",
                                label: "Age",
                                value: viewModel.birthDate.map { ageDisplay($0) } ?? "Not set"
                            ) { showingBirthdatePicker = true }

                            rowDivider

                            editRow(
                                icon: "person.fill",
                                label: "Gender",
                                value: viewModel.gender?.displayText ?? "Select"
                            ) { showingGenderPicker = true }

                            rowDivider

                            occupationRow
                        }
                    }

                    formSectionLabel("Social Media")
                    formCard {
                        HStack(spacing: AppSpacingV3.md) {
                            Text("IG")
                                .font(AppTypographyV3.labelSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorsV3.forestGreen)
                                .frame(width: 24)

                            TextField("Instagram username", text: $viewModel.instagramUsername)
                                .font(AppTypographyV3.bodyMedium)
                                .foregroundColor(AppColorsV3.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(AppSpacingV3.md)
                    }

                    formSectionLabel("Golf Profile")
                    formCard {
                        VStack(spacing: 0) {
                            editRow(
                                icon: "figure.golf",
                                label: "Skill Level",
                                value: viewModel.skillLevel?.displayText ?? "Not set"
                            ) { showingSkillPicker = true }

                            rowDivider

                            editRow(
                                icon: "calendar",
                                label: "Plays per Month",
                                value: viewModel.playsPerMonth.map { "\($0)x / month" } ?? "Optional"
                            ) { showingPlaysPicker = true }

                            rowDivider

                            editRow(
                                icon: "chart.bar",
                                label: "Avg Score",
                                value: viewModel.avgScore.map { "\($0)+" } ?? "Optional"
                            ) { showingScorePicker = true }
                        }
                    }

                    Spacer(minLength: AppSpacingV3.xxl)
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                        .font(AppTypographyV3.bodySemibold)
                        .foregroundColor(AppColorsV3.forestGreen)
                }
            }
        }
        .background(AppColorsV3.bgNeutral.ignoresSafeArea())
        .overlay {
            if viewModel.isSaving || viewModel.isUploadingPhoto {
                loadingOverlay
            }
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
        .sheet(isPresented: $showingGenderPicker) { genderPickerSheet }
        .sheet(isPresented: $showingBirthdatePicker) { birthdatePickerSheet }
        .sheet(isPresented: $showingSkillPicker) { skillLevelPickerSheet }
        .sheet(isPresented: $showingPlaysPicker) { playsPerMonthPickerSheet }
        .sheet(isPresented: $showingScorePicker) { avgScorePickerSheet }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    while !viewModel.photoUrls.isEmpty {
                        await viewModel.deletePhoto(at: 0)
                    }
                    await viewModel.uploadPhoto(image)
                    selectedPhotoItem = nil
                }
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColorsV3.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("Edit Profile")
                .font(AppTypographyV3.bodySemibold)
                .foregroundColor(AppColorsV3.textPrimary)

            Spacer()

            Button {
                Task { await save() }
            } label: {
                Text("Save")
                    .font(AppTypographyV3.bodySemibold)
                    .foregroundColor(viewModel.isSaving ? AppColorsV3.textTertiary : AppColorsV3.forestGreen)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, AppSpacingV3.sm)
        .frame(height: 56)
        .background(AppColorsV3.surfaceWhite)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: AppSpacingV3.sm) {
            photoAvatar
                .onTapGesture { showingPhotoPicker = true }

            Button("Edit Picture") { showingPhotoPicker = true }
                .font(AppTypographyV3.bodySemibold)
                .foregroundColor(AppColorsV3.forestGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacingV3.lg)
        .padding(.bottom, AppSpacingV3.md)
    }

    @ViewBuilder
    private var photoAvatar: some View {
        if let urlString = viewModel.photoUrls.first, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(AppColorsV3.surfaceLight)
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppColorsV3.borderLight, lineWidth: 1.5))
        } else {
            Circle()
                .fill(AppColorsV3.surfaceLight)
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColorsV3.textTertiary)
                )
        }
    }

    // MARK: - Bio Row

    private var bioRow: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.xs) {
            Text("Bio")
                .font(AppTypographyV3.labelSmall)
                .foregroundColor(AppColorsV3.textSecondary)

            TextField("Tell golfers about yourself...", text: $viewModel.bio, axis: .vertical)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textPrimary)
                .lineLimit(3...5)
                .textInputAutocapitalization(.sentences)
                .onChange(of: viewModel.bio) { _, newValue in
                    if newValue.count > 300 {
                        viewModel.bio = String(newValue.prefix(300))
                    }
                }

            if !viewModel.bio.isEmpty {
                Text("\(viewModel.bio.count)/300")
                    .font(AppTypographyV3.caption)
                    .foregroundColor(viewModel.bio.count >= 300 ? AppColorsV3.error : AppColorsV3.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(AppSpacingV3.md)
    }

    // MARK: - Occupation Row

    private var occupationRow: some View {
        HStack(spacing: AppSpacingV3.md) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 15))
                .foregroundColor(AppColorsV3.forestGreen)
                .frame(width: 24)

            Text("Occupation")
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textPrimary)

            Spacer()

            TextField("Optional", text: $viewModel.occupation)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .frame(maxWidth: 160)
        }
        .padding(AppSpacingV3.md)
        .contentShape(Rectangle())
    }

    // MARK: - Layout Helpers

    private func formSectionLabel(_ title: String) -> some View {
        SectionLabelV3(title: title, size: 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacingV3.lg)
            .padding(.bottom, AppSpacingV3.xs)
    }

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(AppColorsV3.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColorsV3.borderLight, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, AppSpacingV3.md + 24 + AppSpacingV3.md)
    }

    private func editRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        let isUnset = value == "Select" || value == "Optional" || value == "Not set"
        return Button(action: action) {
            HStack(spacing: AppSpacingV3.md) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(width: 24)

                Text(label)
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textPrimary)

                Spacer()

                Text(value)
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(isUnset ? AppColorsV3.textTertiary : AppColorsV3.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColorsV3.textTertiary)
            }
            .padding(AppSpacingV3.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func ageDisplay(_ date: Date) -> String {
        let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return "\(age) Years"
    }

    // MARK: - Picker Sheets

    private var genderPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Button {
                        viewModel.gender = gender
                        showingGenderPicker = false
                    } label: {
                        HStack {
                            Text(gender.displayText).foregroundColor(AppColorsV3.textPrimary)
                            Spacer()
                            if viewModel.gender == gender {
                                Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingGenderPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var birthdatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Birth Date",
                selection: Binding(
                    get: { viewModel.birthDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date() },
                    set: { viewModel.birthDate = $0 }
                ),
                in: ...Date.now.addingTimeInterval(-18 * 365.25 * 24 * 60 * 60),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColorsV3.forestGreen)
            .padding()
            .navigationTitle("Birth Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingBirthdatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingBirthdatePicker = false }
                        .foregroundColor(AppColorsV3.forestGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var skillLevelPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Button {
                        viewModel.skillLevel = level
                        showingSkillPicker = false
                    } label: {
                        HStack {
                            Text(level.displayText).foregroundColor(AppColorsV3.textPrimary)
                            Spacer()
                            if viewModel.skillLevel == level {
                                Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Skill Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSkillPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var playsPerMonthPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.playsPerMonth = nil
                    showingPlaysPicker = false
                } label: {
                    HStack {
                        Text("Not set").foregroundColor(AppColorsV3.textTertiary)
                        Spacer()
                        if viewModel.playsPerMonth == nil {
                            Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                        }
                    }
                }

                ForEach([1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20], id: \.self) { count in
                    Button {
                        viewModel.playsPerMonth = count
                        showingPlaysPicker = false
                    } label: {
                        HStack {
                            Text("\(count)x / month").foregroundColor(AppColorsV3.textPrimary)
                            Spacer()
                            if viewModel.playsPerMonth == count {
                                Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plays per Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPlaysPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var avgScorePickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.avgScore = nil
                    showingScorePicker = false
                } label: {
                    HStack {
                        Text("Not set").foregroundColor(AppColorsV3.textTertiary)
                        Spacer()
                        if viewModel.avgScore == nil {
                            Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                        }
                    }
                }

                ForEach(AvgScoreOption.allCases) { option in
                    Button {
                        viewModel.avgScore = option.rawValue
                        showingScorePicker = false
                    } label: {
                        HStack {
                            Text(option.displayText).foregroundColor(AppColorsV3.textPrimary)
                            Spacer()
                            if viewModel.avgScore == option.rawValue {
                                Image(systemName: "checkmark").foregroundColor(AppColorsV3.forestGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Average Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingScorePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func save() async {
        let success = await viewModel.saveProfile()
        if success {
            onSave()
            dismiss()
        }
    }

    // MARK: - Loading Overlay

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
}
