import SwiftUI

/// Sheet for editing personal details (location, age, gender).
struct AboutMeEditSheet: View {
    @StateObject private var viewModel: ProfileEditViewModel
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss

    @State private var showingCitySearch = false
    @State private var showingGenderPicker = false
    @State private var showingBirthdatePicker = false

    let onSave: () -> Void

    init(viewModel: ProfileEditViewModel, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        sectionHeader("LOCATION")

                        AppCard(style: .flat) {
                            tapToEditRow(
                                icon: "location.fill",
                                label: "City",
                                value: viewModel.primaryCityLabel.isEmpty ? "Select" : viewModel.primaryCityLabel
                            ) {
                                showingCitySearch = true
                            }
                        }

                        sectionHeader("PERSONAL")

                        AppCard(style: .flat) {
                            VStack(spacing: 0) {
                                tapToEditRow(
                                    icon: "calendar",
                                    label: "Age",
                                    value: viewModel.birthDate.map {
                                        "\(Calendar.current.component(.year, from: Date()) - Calendar.current.component(.year, from: $0))"
                                    } ?? "Not set"
                                ) {
                                    showingBirthdatePicker = true
                                }

                                Divider()

                                tapToEditRow(
                                    icon: "person.fill",
                                    label: "Gender",
                                    value: viewModel.gender?.displayText ?? "Select"
                                ) {
                                    showingGenderPicker = true
                                }
                            }
                        }

                        sectionHeader("SOCIAL MEDIA")

                        AppCard(style: .flat) {
                            socialMediaRow(
                                label: "IG",
                                placeholder: "Instagram username",
                                text: $viewModel.instagramUsername
                            )
                        }

                        Spacer(minLength: AppSpacing.xxl)
                    }
                    .padding(AppSpacing.contentPadding)
                }
            }
            .navigationTitle("About Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(viewModel.isSaving || !canSave)
                }
            }
            .overlay {
                if viewModel.isSaving {
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
            .sheet(isPresented: $showingGenderPicker) {
                genderPickerSheet
            }
            .sheet(isPresented: $showingBirthdatePicker) {
                birthdatePickerSheet
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !viewModel.primaryCityLabel.isEmpty &&
        viewModel.gender != nil &&
        viewModel.birthDate != nil
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.labelMedium)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)
    }

    private func tapToEditRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 24)

                Text(label)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(value)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func socialMediaRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(label)
                .font(AppTypography.labelSmall)
                .foregroundColor(AppColors.primary)
                .fontWeight(.semibold)
                .frame(width: 24)

            TextField(placeholder, text: text)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.default)
        }
        .padding(AppSpacing.md)
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
                            Text(gender.displayText)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if viewModel.gender == gender {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
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
            .padding()
            .navigationTitle("Birth Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingBirthdatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingBirthdatePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
