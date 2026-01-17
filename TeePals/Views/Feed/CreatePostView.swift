import SwiftUI
import PhotosUI

/// View for creating a new post with full-screen modal UI.
/// Supports title, text, photos (up to 4), and optional round linking.
struct CreatePostView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreatePostViewModel
    @FocusState private var textFocused: Bool

    let onPostCreated: (Post) -> Void

    init(viewModel: CreatePostViewModel, onPostCreated: @escaping (Post) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onPostCreated = onPostCreated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title input
                        titleSection

                        Divider()
                            .padding(.horizontal, AppSpacing.contentPadding)

                        // Text input
                        textSection

                        // Photo grid
                        if !viewModel.photoImages.isEmpty {
                            photoPreviewSection
                        }

                        // Linked round
                        if let round = viewModel.linkedRound {
                            linkedRoundSection(round)
                                .padding(.horizontal, AppSpacing.contentPadding)
                                .padding(.top, AppSpacing.md)
                        }

                        // Error
                        if let error = viewModel.errorMessage {
                            InlineErrorBanner(error)
                                .padding(.horizontal, AppSpacing.contentPadding)
                                .padding(.top, AppSpacing.md)
                        }

                        // Bottom padding for action bar
                        Color.clear.frame(height: 60)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .background(AppColors.backgroundGrouped)

                // Action buttons bar (stays above keyboard)
                actionButtonsBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            if let post = await viewModel.createPost() {
                                onPostCreated(post)
                                dismiss()
                            }
                        }
                    }
                    .font(AppTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.canPost ? AppColors.primary : AppColors.textTertiary)
                    .disabled(!viewModel.canPost)
                }
            }
            .sheet(isPresented: $viewModel.isShowingRoundPicker) {
                roundPickerSheet
            }
            .onChange(of: viewModel.selectedPhotos) {
                Task { await viewModel.loadPhotos() }
            }
            .overlay {
                if viewModel.isUploadingPhotos {
                    uploadingOverlay
                }
            }
        }
    }

    // MARK: - Action Buttons Bar

    private var actionButtonsBar: some View {
        let remainingPhotos = viewModel.remainingPhotos

        return VStack(spacing: 0) {
            Divider()

            HStack(spacing: AppSpacing.lg) {
                // Add photos
                PhotosPicker(
                    selection: $viewModel.selectedPhotos,
                    maxSelectionCount: remainingPhotos,
                    matching: .images
                ) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(remainingPhotos > 0 ? AppColors.primary : AppColors.textTertiary)
                }
                .disabled(remainingPhotos <= 0)

                // Link round
                Button {
                    viewModel.isShowingRoundPicker = true
                    Task { await viewModel.loadRecentRounds() }
                } label: {
                    Image(systemName: "flag")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }

                Spacer()

                // Visibility picker
                Menu {
                    ForEach(PostVisibility.allCases, id: \.self) { visibility in
                        Button {
                            viewModel.visibility = visibility
                        } label: {
                            HStack {
                                Text(visibility.displayText)
                                if viewModel.visibility == visibility {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: viewModel.visibility.icon)
                        .font(.title3)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surface)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            UIKitTextField(
                text: $viewModel.title,
                placeholder: "Write a specific title",
                font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                maxLength: viewModel.maxTitleLength
            )
            .frame(height: 44)
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)

            // Character count
            HStack {
                Spacer()
                Text("\(viewModel.titleCharacterCount)/\(viewModel.maxTitleLength)")
                    .font(AppTypography.caption)
                    .foregroundColor(
                        viewModel.titleCharacterCount > viewModel.maxTitleLength
                        ? AppColors.error
                        : AppColors.textTertiary
                    )
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.sm)
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.text)
                    .font(AppTypography.bodyMedium)
                    .scrollContentBackground(.hidden)
                    .focused($textFocused)
                    .frame(minHeight: 200)
                    .padding(.horizontal, AppSpacing.contentPadding - 4)
                    .padding(.top, AppSpacing.md)

                if viewModel.text.isEmpty {
                    Text("Start a conversation.\nKeep it classy. No personal information or trade secrets.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.contentPadding)
                        .padding(.top, AppSpacing.md + 8)
                        .allowsHitTesting(false)
                }
            }

            // Character count
            HStack {
                Spacer()
                Text("\(viewModel.textCharacterCount)/\(viewModel.maxTextLength)")
                    .font(AppTypography.caption)
                    .foregroundColor(
                        viewModel.textCharacterCount > viewModel.maxTextLength
                        ? AppColors.error
                        : AppColors.textTertiary
                    )
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.md)
        }
    }

    // MARK: - Photo Preview

    private var photoPreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(viewModel.photoImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))

                        Button {
                            viewModel.removePhoto(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Linked Round

    private func linkedRoundSection(_ round: Round) -> some View {
        HStack {
            Image(systemName: "flag.fill")
                .foregroundColor(AppColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(round.displayCourseName)
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textPrimary)

                if let dateTime = round.displayDateTime {
                    Text(dateTime)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.removeLinkedRound()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.sm)
    }

    // MARK: - Round Picker Sheet

    private var roundPickerSheet: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingRounds {
                    ProgressView()
                } else if viewModel.recentRounds.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "flag.slash")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.textTertiary)

                        Text("No rounds to link")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.recentRounds) { round in
                        Button {
                            viewModel.selectRound(round)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(round.displayCourseName)
                                    .font(AppTypography.labelLarge)
                                    .foregroundColor(AppColors.textPrimary)

                                if let dateTime = round.displayDateTime {
                                    Text(dateTime)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link a Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isShowingRoundPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Uploading Overlay

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("Uploading photos...")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.md)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CreatePostView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePostView(
            viewModel: CreatePostViewModel(
                postsRepository: MockPostsRepo(),
                roundsRepository: MockRoundsRepo(),
                storageService: MockStorage(),
                currentUid: { "user1" }
            ),
            onPostCreated: { _ in }
        )
    }

    private class MockPostsRepo: PostsRepository {
        func createPost(_ post: Post) async throws -> Post { post }
        func fetchPost(id: String) async throws -> Post? { nil }
        func updatePost(_ post: Post) async throws {}
        func deletePost(id: String) async throws {}
        func updateAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws {}
        func fetchFeed(filter: FeedFilter, limit: Int, after: Date?) async throws -> [Post] { [] }
        func fetchUserPosts(uid: String, limit: Int, after: Date?) async throws -> [Post] { [] }
        func toggleUpvote(postId: String) async throws -> Bool { false }
        func hasUpvoted(postId: String) async throws -> Bool { false }
        func createComment(_ comment: Comment) async throws -> Comment { comment }
        func fetchComments(postId: String) async throws -> [Comment] { [] }
        func updateComment(_ comment: Comment) async throws {}
        func deleteComment(postId: String, commentId: String) async throws {}

        // Phase 4.2 methods
        func fetchFriendsPostsCandidates(authorUids: [String], windowStart: Date, limit: Int) async throws -> [Post] { [] }
        func fetchRecentPublicPosts(windowStart: Date, limit: Int) async throws -> [Post] { [] }
        func fetchTrendingPostIds(limit: Int) async throws -> [(String, Double)] { [] }
        func fetchPostsByIds(_ ids: [String]) async throws -> [Post] { [] }
        func fetchNewCreatorsPosts(windowStart: Date, limit: Int) async throws -> [Post] { [] }
        func fetchPostStats(postId: String) async throws -> PostStats? { nil }
        func fetchPostStatsBatch(postIds: [String]) async throws -> [String: PostStats] { [:] }
        func fetchUserStats(uid: String) async throws -> UserStats? { nil }
        func fetchUserStatsBatch(uids: [String]) async throws -> [String: UserStats] { [:] }
    }

    private class MockRoundsRepo: RoundsRepository {
        func createRound(_ round: Round) async throws -> Round { round }
        func fetchRound(id: String) async throws -> Round? { nil }
        func fetchRounds(filters: RoundFilters, limit: Int, lastRound: Round?) async throws -> [Round] { [] }
        func updateRound(_ round: Round) async throws {}
        func cancelRound(id: String) async throws {}
        func fetchMembers(roundId: String) async throws -> [RoundMember] { [] }
        func requestToJoin(roundId: String) async throws {}
        func joinRound(roundId: String) async throws {}
        func acceptMember(roundId: String, memberUid: String) async throws {}
        func declineMember(roundId: String, memberUid: String) async throws {}
        func removeMember(roundId: String, memberUid: String) async throws {}
        func leaveRound(roundId: String) async throws {}
        func inviteMember(roundId: String, targetUid: String) async throws {}
        func fetchMembershipStatus(roundId: String) async throws -> RoundMember? { nil }
        func fetchInvitedRounds() async throws -> [Round] { [] }
        func acceptInvite(roundId: String) async throws {}
        func declineInvite(roundId: String) async throws {}
    }

    private class MockStorage: StorageServiceProtocol {
        func uploadProfilePhoto(_ imageData: Data) async throws -> String { "" }
        func deleteProfilePhoto(url: String) async throws {}
        func uploadPostPhoto(_ imageData: Data, postId: String?) async throws -> String { "" }
        func deletePostPhoto(url: String) async throws {}
        func uploadChatPhoto(_ imageData: Data, roundId: String, messageId: String?) async throws -> String { "" }
    }
}
#endif

// MARK: - UIKit TextField Wrapper

/// UIKit TextField wrapper that becomes first responder immediately when created.
/// This allows the keyboard to animate up during the modal presentation.
struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let maxLength: Int

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = font
        textField.delegate = context.coordinator
        textField.returnKeyType = .next
        textField.autocapitalizationType = .sentences
        textField.autocorrectionType = .default

        // Become first responder immediately - keyboard starts animating with modal
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, maxLength: maxLength)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let maxLength: Int

        init(text: Binding<String>, maxLength: Int) {
            _text = text
            self.maxLength = maxLength
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)

            // Update binding
            text = updatedText

            // Enforce max length
            return updatedText.count <= maxLength
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

