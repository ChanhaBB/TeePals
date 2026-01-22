import SwiftUI

/// Detail view for a single post with comments.
/// Supports upvoting, editing, deleting, and nested comments.
struct PostDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppContainer
    @StateObject private var viewModel: PostDetailViewModel

    @State private var selectedAuthorUid: String?
    @State private var selectedRoundId: String?
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex = 0
    @State private var commentInputState: CommentInputState = .resting

    // STEP 4: Removed redundant @State isCommentFocused
    // Computed binding derives focus from inputState (single source of truth)
    // This binding ensures isCommentFocused and inputState never drift out of sync
    private var isCommentFocusedBinding: Binding<Bool> {
        Binding(
            get: {
                // Derive from inputState (source of truth)
                commentInputState == .active
            },
            set: { newValue in
                // Update inputState based on focus change
                if newValue {
                    commentInputState = .active
                } else {
                    // When unfocusing, check if we have draft
                    commentInputState = viewModel.hasDraft ? .draft : .resting
                }
            }
        )
    }

    let onDeleted: (String) -> Void
    let onUpdated: (Post) -> Void
    
    init(
        viewModel: PostDetailViewModel,
        onDeleted: @escaping (String) -> Void,
        onUpdated: @escaping (Post) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onDeleted = onDeleted
        self.onUpdated = onUpdated
    }

    // No longer needed - state management is handled within CommentComposerSheet

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Custom navigation bar
                customNavigationBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let post = viewModel.post {
                    ZStack {
                        AppColors.backgroundGrouped.ignoresSafeArea()

                        // Entire page scrollable (post + comments)
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                // Post content card
                                VStack(alignment: .leading, spacing: 0) {
                                    postContent(post)
                                }
                                .background(AppColors.surface)

                                // Comments section card
                                VStack(alignment: .leading, spacing: 0) {
                                    commentsSection
                                }
                                .background(AppColors.surface)
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack {
                        Text(error)
                            .foregroundColor(AppColors.error)
                        Button("Retry") {
                            Task { await viewModel.loadPost() }
                        }
                    }
                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)

            // Comment input bar at bottom - slides up naturally with keyboard
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // STEP 1: Reply banner (only shown when replying)
                    if let replyTarget = viewModel.replyingTo {
                        replyBanner(replyTarget)
                    }

                    CommentInputBar(
                        viewModel: viewModel,
                        isCommentFocused: isCommentFocusedBinding,
                        inputState: $commentInputState,
                        userProfilePhotoUrl: container.currentUserProfilePhotoUrl,
                        onActivate: { activateComposer(replyTo: nil) }
                    )
                }
            }
        }
        .alert("Delete Post?", isPresented: $viewModel.isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deletePost() {
                        onDeleted(viewModel.postId)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        // STEP 3: Use commentInputState (source of truth) instead of isCommentFocused
        .interactiveDismissDisabled(commentInputState != .resting)
        .onAppear {
            // Wire up the callback
            viewModel.onPostUpdated = onUpdated
        }
        .onDisappear {
            // Clear draft when leaving post
            viewModel.commentDraft = ""
            viewModel.newCommentText = ""
        }
        .sheet(item: Binding(
            get: { selectedAuthorUid.map { IdentifiableString(value: $0) } },
            set: { selectedAuthorUid = $0?.value }
        )) { wrapper in
            if wrapper.value == viewModel.uid {
                // Show own profile
                NavigationStack {
                    ProfileView(viewModel: container.makeProfileViewModel())
                }
            } else {
                // Show other user's profile
                NavigationStack {
                    OtherUserProfileView(
                        viewModel: container.makeOtherUserProfileViewModel(uid: wrapper.value)
                    )
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedRoundId.map { IdentifiableString(value: $0) } },
            set: { selectedRoundId = $0?.value }
        )) { wrapper in
            NavigationStack {
                RoundDetailView(
                    viewModel: container.makeRoundDetailViewModel(roundId: wrapper.value)
                )
            }
        }
        .task {
            await viewModel.loadPost()
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let post = viewModel.post {
                PhotoViewerView(photoUrls: post.photoUrls, initialIndex: selectedPhotoIndex)
            }
        }
    }

    // MARK: - Composer Activation

    /// Single entry point for activating the comment composer
    private func activateComposer(replyTo: Comment?) {
        // Set reply target if provided
        if let comment = replyTo {
            viewModel.setReplyTarget(comment)
        } else {
            viewModel.setReplyTarget(nil)
            if viewModel.hasDraft && viewModel.newCommentText.isEmpty {
                viewModel.newCommentText = viewModel.commentDraft
            }
        }

        // Focus the composer
        commentInputState = .active
    }

    // MARK: - Custom Navigation Bar

    private var customNavigationBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Back button with TeePals text
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)

                    Text("TeePals")
                        .font(AppTypography.labelLarge)
                }
                .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            // Three dots menu
            Menu {
                if viewModel.isAuthor {
                    Button {
                        viewModel.startEditing()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        viewModel.isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Button {
                    // TODO: Share post
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    // TODO: Report post
                } label: {
                    Label("Report", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface)
    }
    
    // MARK: - Post Content

    private func postContent(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header (tappable to view profile)
            Button {
                selectedAuthorUid = post.authorUid
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    avatarView(post)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorNickname ?? "Unknown")
                            .font(AppTypography.labelLarge)
                            .foregroundColor(AppColors.textPrimary)

                        Text(post.fullDateString)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    if post.visibility == .friends {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content section with spacing
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Title
                if let title = post.title, !title.isEmpty {
                    Text(title)
                        .font(AppTypography.headlineLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }

                // Edit mode or display mode
                if viewModel.isEditing {
                    editTextView
                } else {
                    Text(post.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }

                if post.isEdited && !viewModel.isEditing {
                    Text("Edited")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                // Photos
                if post.hasPhotos {
                    photoSection(post.photoUrls)
                        .padding(.top, AppSpacing.md)
                }

                // Linked round
                if let round = viewModel.linkedRound {
                    linkedRoundCard(round)
                        .padding(.top, AppSpacing.sm)
                }
            }
            .padding(.top, AppSpacing.lg)

            // Separator before interactions
            Rectangle()
                .fill(AppColors.textTertiary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)

            // Interactions
            interactionsBar(post)
        }
        .padding(AppSpacing.contentPadding)
    }
    
    private func avatarView(_ post: Post) -> some View {
        Group {
            if let photoUrl = post.authorPhotoUrl, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView(post.authorNickname)
                }
            } else {
                initialsView(post.authorNickname)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    private func initialsView(_ nickname: String?) -> some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Text(String(nickname?.prefix(1) ?? "?"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.primary)
            )
    }
    
    private var editTextView: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.sm) {
            TextEditor(text: $viewModel.editText)
                .font(AppTypography.bodyMedium)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.sm)
            
            HStack {
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                .foregroundColor(AppColors.textSecondary)
                
                Button("Save") {
                    Task { await viewModel.saveEdit() }
                }
                .font(AppTypography.labelLarge)
                .foregroundColor(AppColors.primary)
                .disabled(viewModel.isSaving)
            }
        }
    }
    
    private func photoSection(_ urls: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    CachedAsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(AppColors.backgroundSecondary)
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPhotoIndex = index
                        showPhotoViewer = true
                    }
                }
            }
        }
    }
    
    private func linkedRoundCard(_ round: Round) -> some View {
        Button {
            // Only navigate if round is active (open status)
            if round.status == .open, let roundId = round.id {
                selectedRoundId = roundId
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Linked Round")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)

                    if round.status != .open {
                        Text("(\(round.status.displayText))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    if round.status == .open {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

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
                }
                .padding(AppSpacing.sm)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .disabled(round.status != .open)
    }
    
    private func interactionsBar(_ post: Post) -> some View {
        HStack(spacing: AppSpacing.xl) {
            // Like button with text
            Button {
                Task {
                    await viewModel.toggleUpvote()
                    // Notify parent view of upvote change
                    if let updatedPost = viewModel.post {
                        onUpdated(updatedPost)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.hasUpvoted == true ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(post.hasUpvoted == true ? AppColors.error : AppColors.textSecondary)

                    Text("Like")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.textSecondary)

                    if post.upvoteCount > 0 {
                        Text("\(post.upvoteCount)")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Comments count with text
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)

                Text("\(post.commentCount)")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Reply Banner

    private func replyBanner(_ comment: Comment) -> some View {
        HStack(spacing: 8) {
            Text("Replying to @\(comment.authorNickname ?? "user")")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button {
                viewModel.setReplyTarget(nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.textTertiary)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        if let post = viewModel.post {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingComments {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.contentPadding)
                } else if viewModel.commentTree.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.contentPadding)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.commentTree) { comment in
                            CommentRowView(
                                comment: comment,
                                postAuthorUid: post.authorUid,
                                isAuthor: comment.authorUid == viewModel.uid,
                                onReply: {
                                    activateComposer(replyTo: comment)
                                },
                                onLike: { c in Task { await viewModel.toggleCommentLike(c) } },
                                onDelete: { Task { await viewModel.deleteComment(comment) } },
                                onDeleteReply: { reply in
                                    Task { await viewModel.deleteComment(reply) }
                                },
                                onAuthorTap: { uid in
                                    selectedAuthorUid = uid
                                }
                            )

                            // Thin separator line between comments
                            if comment.id != viewModel.commentTree.last?.id {
                                Rectangle()
                                    .fill(AppColors.textTertiary.opacity(0.2))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
    }
}

// MARK: - Note: Comment input components moved to CommentComposer.swift
// See: TeePals/UIComponents/CommentComposer.swift

// MARK: - Note: Comment row components moved to CommentRowView.swift
// See: TeePals/Views/Feed/CommentRowView.swift

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Note: RoundedCornerShape moved to UIFoundation
// See: TeePals/UIFoundation/RoundedCornerShape.swift

// MARK: - Note: UIKit TextView components moved to AdvancedTextEditor.swift
// See: TeePals/UIComponents/AdvancedTextEditor.swift

