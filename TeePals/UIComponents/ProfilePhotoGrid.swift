import SwiftUI
import PhotosUI

/// Grid component for displaying and managing profile photos.
/// Supports up to 5 photos with add/delete, reorder, and two-step upload.
struct ProfilePhotoGrid: View {
    @Binding var photoUrls: [String]
    let isUploading: Bool
    let canAddMore: Bool
    let onAddPhoto: (UIImage) -> Void
    let onDeletePhoto: (Int) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showingPreview = false
    
    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Instructions
            if photoUrls.count > 1 {
                Text("Use arrows to reorder • First photo is your main profile picture")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                // Existing photos
                ForEach(photoUrls.indices, id: \.self) { index in
                    PhotoCell(
                        url: photoUrls[index],
                        isPrimary: index == 0,
                        showMoveUp: index > 0,
                        showMoveDown: index < photoUrls.count - 1,
                        onDelete: {
                            print("🗑️ [ProfilePhotoGrid] Delete tapped for index \(index)")
                            onDeletePhoto(index)
                        },
                        onMoveUp: {
                            print("⬆️ [ProfilePhotoGrid] Move up from index \(index)")
                            onReorder(IndexSet(integer: index), index - 1)
                        },
                        onMoveDown: {
                            print("⬇️ [ProfilePhotoGrid] Move down from index \(index)")
                            onReorder(IndexSet(integer: index), index + 2)
                        }
                    )
                }

                // Upload placeholder (if can add more)
                if canAddMore {
                    addPhotoButton
                }

                // Upload progress indicator
                if isUploading {
                    uploadingCell
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let image = previewImage {
                photoPreviewSheet(image: image)
            }
        }
    }
    
    // MARK: - Add Photo Button
    
    private var addPhotoButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadii.card)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .foregroundStyle(AppColors.textTertiary)

                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppColors.primary)

                    Text("Add")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newValue in
            print("➕ [ProfilePhotoGrid] Add photo picker changed")
            guard let item = newValue else { return }
            loadImage(from: item)
        }
    }
    
    // MARK: - Uploading Cell
    
    private var uploadingCell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadii.card)
                .fill(AppColors.backgroundSecondary)
            
            ProgressView()
                .scaleEffect(1.2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Load Image

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }

            await MainActor.run {
                previewImage = image
                showingPreview = true
                selectedItem = nil
            }
        }
    }

    // MARK: - Photo Preview Sheet

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
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onAddPhoto(image)
                        showingPreview = false
                        previewImage = nil
                    } label: {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Upload")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isUploading)
                }
            }
        }
    }
}

// MARK: - Photo Cell

private struct PhotoCell: View {
    let url: String
    let isPrimary: Bool
    let showMoveUp: Bool
    let showMoveDown: Bool
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                TPImage(url: URL(string: url))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadii.card))

                // Primary badge
                if isPrimary {
                    Text("Main")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(4)
                }

                // Delete button (top right)
                VStack(spacing: 0) {
                    Button {
                        print("🗑️ [PhotoCell] Delete button tapped")
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: isPrimary ? 20 : 0)

                    Spacer()
                }

                // Reorder buttons (bottom left)
                if showMoveUp || showMoveDown {
                    VStack(spacing: 0) {
                        Spacer()

                        HStack(spacing: 4) {
                            if showMoveUp {
                                Button {
                                    print("⬆️ [PhotoCell] Move up tapped")
                                    onMoveUp()
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                            }

                            if showMoveDown {
                                Button {
                                    print("⬇️ [PhotoCell] Move down tapped")
                                    onMoveDown()
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()
                        }
                        .padding(6)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: AppRadii.card)
            .fill(AppColors.backgroundSecondary)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(AppColors.textTertiary)
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        ProfilePhotoGrid(
            photoUrls: .constant([
                "https://picsum.photos/200",
                "https://picsum.photos/201"
            ]),
            isUploading: false,
            canAddMore: true,
            onAddPhoto: { _ in },
            onDeletePhoto: { _ in },
            onReorder: { _, _ in }
        )
    }
    .padding()
}
#endif

