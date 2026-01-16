import SwiftUI

/// Sheet for editing golf details (skill level, plays per month, avg score).
struct GolfEditSheet: View {
    @StateObject private var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingSkillPicker = false
    @State private var showingPlaysPicker = false
    @State private var showingScorePicker = false

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
                        sectionHeader("GOLF DETAILS")

                        AppCard(style: .flat) {
                            VStack(spacing: 0) {
                                tapToEditRow(
                                    icon: "chart.bar.fill",
                                    label: "Skill Level",
                                    value: viewModel.skillLevel?.displayText ?? "Not set"
                                ) {
                                    showingSkillPicker = true
                                }

                                Divider()

                                tapToEditRow(
                                    icon: "calendar.badge.clock",
                                    label: "Plays per Month",
                                    value: viewModel.playsPerMonth.map { "\($0) times" } ?? "Optional"
                                ) {
                                    showingPlaysPicker = true
                                }

                                Divider()

                                tapToEditRow(
                                    icon: "number",
                                    label: "Average Score",
                                    value: viewModel.avgScore.map { "\($0)+" } ?? "Optional"
                                ) {
                                    showingScorePicker = true
                                }
                            }
                        }

                        Spacer(minLength: AppSpacing.xxl)
                    }
                    .padding(AppSpacing.contentPadding)
                }
            }
            .navigationTitle("Golf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    loadingOverlay
                }
            }
            .sheet(isPresented: $showingSkillPicker) {
                skillLevelPickerSheet
            }
            .sheet(isPresented: $showingPlaysPicker) {
                playsPerMonthPickerSheet
            }
            .sheet(isPresented: $showingScorePicker) {
                avgScorePickerSheet
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    // MARK: - Helpers

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
                    .foregroundColor(value.contains("Optional") || value.contains("Not set") ? AppColors.textTertiary : AppColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Picker Sheets

    private var skillLevelPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Button {
                        viewModel.skillLevel = level
                        showingSkillPicker = false
                    } label: {
                        HStack {
                            Text(level.displayText)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if viewModel.skillLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
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
                clearPlaysButton
                Divider()
                playsOptionsList
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

    private var clearPlaysButton: some View {
        Button {
            viewModel.playsPerMonth = nil
            showingPlaysPicker = false
        } label: {
            HStack {
                Text("Not set")
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                if viewModel.playsPerMonth == nil {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }

    private var playsOptionsList: some View {
        ForEach([1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20], id: \.self) { count in
            Button {
                viewModel.playsPerMonth = count
                showingPlaysPicker = false
            } label: {
                HStack {
                    Text("\(count) times")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if viewModel.playsPerMonth == count {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }

    private var avgScorePickerSheet: some View {
        NavigationStack {
            List {
                clearScoreButton
                Divider()
                scoreOptionsList
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

    private var clearScoreButton: some View {
        Button {
            viewModel.avgScore = nil
            showingScorePicker = false
        } label: {
            HStack {
                Text("Not set")
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                if viewModel.avgScore == nil {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }

    private var scoreOptionsList: some View {
        ForEach(AvgScoreOption.allCases) { option in
            Button {
                viewModel.avgScore = option.rawValue
                showingScorePicker = false
            } label: {
                HStack {
                    Text(option.displayText)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if viewModel.avgScore == option.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
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
