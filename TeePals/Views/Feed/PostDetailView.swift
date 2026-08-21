import SwiftUI

/// Detail view for a single post with comments.
/// Supports upvoting, editing, deleting, and nested comments.
struct PostDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppContainer
    @StateObject private var viewModel: PostDetailViewModel

    @State private var selectedAuthorUid: String?
    @State private var roundDetail: RoundDetailIdentifier?
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex = 0
    @State private var commentInputState: CommentInputState = .resting
    @State private var showReportPostAlert = false
    @State private var showReportPostConfirmation = false
    @State private var showReportCommentAlert = false
    @State private var showReportCommentConfirmation = false
    @State private var reportTargetComment: Comment?

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
                        AppColorsV3.surfaceLight.ignoresSafeArea()

                        // Entire page scrollable (post + comments)
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                                // Post content card
                                VStack(alignment: .leading, spacing: 0) {
                                    postContent(post)
                                }
                                .background(AppColorsV3.surfaceWhite)

                                // Comments section card
                                VStack(alignment: .leading, spacing: 0) {
                                    commentsSection
                                }
                                .background(AppColorsV3.surfaceWhite)
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
                            .foregroundColor(AppColorsV3.error)
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
        .alert("Report Post", isPresented: $showReportPostAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) {
                guard let authorUid = viewModel.post?.authorUid else { return }
                Task {
                    do {
                        let report = Report(
                            reporterUid: container.currentUid ?? "",
                            reportedUid: authorUid,
                            reason: "Inappropriate post",
                            context: "post:\(viewModel.postId)"
                        )
                        try await container.reportRepository.submitReport(report: report)
                        showReportPostConfirmation = true
                    } catch {
                        print("Failed to report post: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to report this post? Our team will review the report.")
        }
        .alert("Thank You", isPresented: $showReportPostConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your report has been submitted. We'll review it shortly.")
        }
        .alert("Report Comment", isPresented: $showReportCommentAlert) {
            Button("Cancel", role: .cancel) { reportTargetComment = nil }
            Button("Report", role: .destructive) {
                guard let comment = reportTargetComment else { return }
                Task {
                    do {
                        let report = Report(
                            reporterUid: container.currentUid ?? "",
                            reportedUid: comment.authorUid,
                            reason: "Inappropriate comment",
                            context: "comment:\(comment.id ?? "unknown") on post:\(viewModel.postId)"
                        )
                        try await container.reportRepository.submitReport(report: report)
                        reportTargetComment = nil
                        showReportCommentConfirmation = true
                    } catch {
                        print("Failed to report comment: \(error)")
                        reportTargetComment = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to report this comment? Our team will review the report.")
        }
        .alert("Thank You", isPresented: $showReportCommentConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your report has been submitted. We'll review it shortly.")
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
        .fullScreenCover(item: Binding(
            get: { selectedAuthorUid.map { IdentifiableString(value: $0) } },
            set: { selectedAuthorUid = $0?.value }
        )) { wrapper in
            ProfileViewV3(viewModel: container.makeProfileViewModel(uid: wrapper.value), isPresented: true)
                .environmentObject(container)
        }
        .fullScreenCover(item: $roundDetail) { item in
            RoundDetailCover(roundId: item.roundId)
                .environmentObject(container)
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
        HStack(spacing: AppSpacingV3.xs) {
            // Back button with TeePals text
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)

                    Text("TeePals")
                        .font(AppTypographyV3.bodySemibold)
                }
                .foregroundColor(AppColorsV3.textPrimary)
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

                if !viewModel.isAuthor {
                    Button(role: .destructive) {
                        showReportPostAlert = true
                    } label: {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(AppColorsV3.textPrimary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, AppSpacingV3.md)
        .padding(.vertical, AppSpacingV3.xs)
        .background(AppColorsV3.surfaceWhite)
    }
    
    // MARK: - Post Content

    private func postContent(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header (tappable to view profile)
            Button {
                selectedAuthorUid = post.authorUid
            } label: {
                HStack(spacing: AppSpacingV3.xs) {
                    avatarView(post)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorNickname ?? "Unknown")
                            .font(AppTypographyV3.bodySemibold)
                            .foregroundColor(AppColorsV3.textPrimary)

                        Text(post.fullDateString)
                            .font(AppTypographyV3.caption)
                            .foregroundColor(AppColorsV3.textTertiary)
                    }

                    Spacer()

                    if post.visibility == .friends {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(AppColorsV3.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content section with spacing
            VStack(alignment: .leading, spacing: AppSpacingV3.xs) {
                // Title
                if let title = post.title, !title.isEmpty {
                    Text(title)
                        .font(AppTypographyV3.headlineLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColorsV3.textPrimary)
                }

                // Edit mode or display mode
                if viewModel.isEditing {
                    editTextView
                } else {
                    Text(post.text)
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textPrimary)
                }

                if post.isEdited && !viewModel.isEditing {
                    Text("Edited")
                        .font(AppTypographyV3.caption)
                        .foregroundColor(AppColorsV3.textTertiary)
                }

                // Photos
                if post.hasPhotos {
                    photoSection(post.photoUrls)
                        .padding(.top, AppSpacingV3.md)
                }

                // Linked round
                if let round = viewModel.linkedRound {
                    linkedRoundCard(round)
                        .padding(.top, AppSpacingV3.xs)
                }
            }
            .padding(.top, AppSpacingV3.md)

            // Separator before interactions
            Rectangle()
                .fill(AppColorsV3.textTertiary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, AppSpacingV3.xs)
                .padding(.top, AppSpacingV3.md)
                .padding(.bottom, AppSpacingV3.xxs)

            // Interactions
            interactionsBar(post)
        }
        .padding(AppSpacingV3.md)
    }
    
    private func avatarView(_ post: Post) -> some View {
        TPAvatar(
            url: post.authorPhotoUrl.flatMap { URL(string: $0) },
            size: 44
        )
    }
    
    private func initialsView(_ nickname: String?) -> some View {
        Circle()
            .fill(AppColorsV3.forestGreen.opacity(0.15))
            .overlay(
                Text(String(nickname?.prefix(1) ?? "?"))
                    .font(AppTypographyV3.bodySemibold)
                    .foregroundColor(AppColorsV3.forestGreen)
            )
    }
    
    private var editTextView: some View {
        VStack(alignment: .trailing, spacing: AppSpacingV3.xs) {
            TextEditor(text: $viewModel.editText)
                .font(AppTypographyV3.bodyMedium)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .background(AppColorsV3.surfaceLight)
                .cornerRadius(AppSpacingV3.xs)
            
            HStack {
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                .foregroundColor(AppColorsV3.textSecondary)
                
                Button("Save") {
                    Task { await viewModel.saveEdit() }
                }
                .font(AppTypographyV3.bodySemibold)
                .foregroundColor(AppColorsV3.forestGreen)
                .disabled(viewModel.isSaving)
            }
        }
    }
    
    private func photoSection(_ urls: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacingV3.xs) {
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    TPImage(url: URL(string: url))
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.xs))
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
                roundDetail = RoundDetailIdentifier(roundId: roundId)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Linked Round")
                        .font(AppTypographyV3.caption)
                        .foregroundColor(AppColorsV3.textTertiary)

                    if round.status != .open {
                        Text("(\(round.status.displayText))")
                            .font(AppTypographyV3.caption)
                            .foregroundColor(AppColorsV3.textTertiary)
                    }

                    Spacer()

                    if round.status == .open {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColorsV3.textTertiary)
                    }
                }

                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(AppColorsV3.forestGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.displayCourseName)
                            .font(AppTypographyV3.bodySemibold)
                            .foregroundColor(AppColorsV3.textPrimary)

                        if let dateTime = round.displayDateTime {
                            Text(dateTime)
                                .font(AppTypographyV3.caption)
                                .foregroundColor(AppColorsV3.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(AppSpacingV3.xs)
                .background(AppColorsV3.surfaceWhite)
                .cornerRadius(AppSpacingV3.xs)
            }
        }
        .buttonStyle(.plain)
        .disabled(round.status != .open)
    }
    
    private func interactionsBar(_ post: Post) -> some View {
        HStack(spacing: AppSpacingV3.lg) {
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
                        .foregroundColor(post.hasUpvoted == true ? AppColorsV3.error : AppColorsV3.textSecondary)

                    Text("Like")
                        .font(AppTypographyV3.labelMedium)
                        .foregroundColor(AppColorsV3.textSecondary)

                    if post.upvoteCount > 0 {
                        Text("\(post.upvoteCount)")
                            .font(AppTypographyV3.labelMedium)
                            .foregroundColor(AppColorsV3.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Comments count with text
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundColor(AppColorsV3.textSecondary)

                Text("\(post.commentCount)")
                    .font(AppTypographyV3.labelMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacingV3.md)
    }

    // MARK: - Reply Banner

    private func replyBanner(_ comment: Comment) -> some View {
        HStack(spacing: 8) {
            Text("Replying to @\(comment.authorNickname ?? "user")")
                .font(AppTypographyV3.caption)
                .foregroundColor(AppColorsV3.textSecondary)

            Spacer()

            Button {
                viewModel.setReplyTarget(nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColorsV3.textTertiary)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, AppSpacingV3.md)
        .padding(.vertical, AppSpacingV3.xs)
        .background(AppColorsV3.surfaceLight)
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        if let post = viewModel.post {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingComments {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacingV3.md)
                } else if viewModel.commentTree.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppSpacingV3.md)
                        .padding(.horizontal, AppSpacingV3.md)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.commentTree) { comment in
                            CommentRowView(
                                comment: comment,
                                currentUserUid: viewModel.uid,
                                postAuthorUid: post.authorUid,
                                onReply: { commentToReplyTo in
                                    activateComposer(replyTo: commentToReplyTo)
                                },
                                onLike: { c in Task { await viewModel.toggleCommentLike(c) } },
                                onDelete: { Task { await viewModel.deleteComment(comment) } },
                                onDeleteReply: { reply in
                                    Task { await viewModel.deleteComment(reply) }
                                },
                                onAuthorTap: { uid in
                                    selectedAuthorUid = uid
                                },
                                onReport: { commentToReport in
                                    reportTargetComment = commentToReport
                                    showReportCommentAlert = true
                                }
                            )

                            // Thin separator line between comments
                            if comment.id != viewModel.commentTree.last?.id {
                                Rectangle()
                                    .fill(AppColorsV3.textTertiary.opacity(0.2))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(.top, AppSpacingV3.xs)
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
