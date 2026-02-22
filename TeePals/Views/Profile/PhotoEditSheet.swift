import SwiftUI
import PhotosUI

/// Sheet for managing single profile photo.
struct PhotoEditSheet: View {
    @StateObject private var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showingPreview = false
    @State private var showingDeleteConfirm = false

    let onSave: () -> Void

    init(viewModel: ProfileEditViewModel, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()

                VStack(spacing: AppSpacing.xl) {
                    Text("Your profile photo")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)

                    // Photo display
                    photoDisplay

                    // Action buttons
                    VStack(spacing: AppSpacing.md) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: hasPhoto ? "arrow.triangle.2.circlepath" : "camera.fill")
                                Text(hasPhoto ? "Change Photo" : "Add Photo")
                            }
                            .font(AppTypography.buttonMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.buttonHeightLarge)
                            .background(AppColors.primary)
                            .cornerRadius(AppRadii.button)
                        }
                        .disabled(viewModel.isUploadingPhoto)

                        if hasPhoto {
                            Button {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove Photo")
                                }
                                .font(AppTypography.buttonMedium)
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppSpacing.buttonHeightLarge)
                                .background(AppColors.surface)
                                .cornerRadius(AppRadii.button)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)

                    Spacer()
                }
                .padding(.top, AppSpacing.xl)
            }
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if viewModel.isUploadingPhoto {
                    loadingOverlay
                }
            }
            .task {
                await viewModel.loadProfile()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        previewImage = image
                        showingPreview = true
                    }
                }
            }
            .sheet(isPresented: $showingPreview) {
                if let image = previewImage {
                    photoPreviewSheet(image: image)
                }
            }
            .alert("Remove Photo", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        await deletePhoto()
                    }
                }
            } message: {
                Text("Are you sure you want to remove your profile photo?")
            }
        }
    }

    // MARK: - Photo Display

    private var photoDisplay: some View {
        TPAvatar(
            url: viewModel.photoUrls.first.flatMap { URL(string: $0) },
            size: 160
        )
        .overlay(
            Circle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var photoPlaceholder: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.primary.opacity(0.6))
            )
    }

    private var hasPhoto: Bool {
        !viewModel.photoUrls.isEmpty
    }

    // MARK: - Preview Sheet

    private func photoPreviewSheet(image: UIImage) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingPreview = false
                        previewImage = nil
                        selectedItem = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        Task {
                            await uploadPhoto(image)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func uploadPhoto(_ image: UIImage) async {
        // If there's an existing photo, remove it first
        if !viewModel.photoUrls.isEmpty {
            await viewModel.deletePhoto(at: 0)
        }

        await viewModel.uploadPhoto(image)

        // Save profile to persist the new photo URL
        let success = await viewModel.saveProfile()
        if success {
            showingPreview = false
            previewImage = nil
            selectedItem = nil
            onSave()
        }
    }

    private func deletePhoto() async {
        guard !viewModel.photoUrls.isEmpty else { return }

        await viewModel.deletePhoto(at: 0)

        // Save profile to persist the removal
        let success = await viewModel.saveProfile()
        if success {
            onSave()
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
