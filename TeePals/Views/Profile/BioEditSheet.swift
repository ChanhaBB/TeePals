import SwiftUI

/// Sheet for editing user bio with character limit.
struct BioEditSheet: View {
    @StateObject private var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var localBio: String = ""
    let characterLimit = 160
    let onSave: () -> Void

    init(viewModel: ProfileEditViewModel, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Tell golfers about yourself")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.contentPadding)

                TextField("Write your bio...", text: $localBio, axis: .vertical)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadii.card)
                    .lineLimit(3...6)
                    .onChange(of: localBio) { _, newValue in
                        if newValue.count > characterLimit {
                            localBio = String(newValue.prefix(characterLimit))
                        }
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)

                HStack {
                    Text("\(localBio.count)/\(characterLimit)")
                        .font(AppTypography.caption)
                        .foregroundColor(localBio.count >= characterLimit ? AppColors.error : AppColors.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.contentPadding)

                Spacer()
            }
            .padding(.top, AppSpacing.md)
            .background(AppColors.backgroundGrouped)
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    loadingOverlay
                }
            }
            .task {
                await viewModel.loadProfile()
                localBio = viewModel.bio
            }
        }
    }

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

    private func save() async {
        viewModel.bio = localBio
        let success = await viewModel.saveProfile()
        if success {
            onSave()
            dismiss()
        }
    }
}
