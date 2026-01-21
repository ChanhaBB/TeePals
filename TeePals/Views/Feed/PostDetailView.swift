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
    @FocusState private var isCommentFocused: Bool
    @State private var commentInputState: CommentInputState = .resting

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
                    // Comment composer is now always visible at bottom via overlay
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
                CommentInputBar(
                    viewModel: viewModel,
                    isCommentFocused: $isCommentFocused,
                    inputState: $commentInputState,
                    userProfilePhotoUrl: container.currentUserProfilePhotoUrl
                )
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
        .onAppear {
            // Wire up the callback
            viewModel.onPostUpdated = onUpdated
        }
        .onDisappear {
            // Clear draft when leaving post
            viewModel.commentDraft = ""
            viewModel.newCommentText = ""
        }
        .onChange(of: viewModel.replyingTo) { _, newValue in
            // Show composer when user taps reply
            if newValue != nil {
                commentInputState = .active
            }
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
                                onReply: { viewModel.setReplyTarget(comment) },
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

// MARK: - Comment Input Bar

// MARK: - Comment Input State
enum CommentInputState {
    case resting  // Not focused, no draft
    case draft    // Not focused, has draft
    case active   // Focused, editing
}

struct CommentInputBar: View {
    @ObservedObject var viewModel: PostDetailViewModel
    @FocusState.Binding var isCommentFocused: Bool
    @Binding var inputState: CommentInputState
    @State private var dynamicHeight: CGFloat = 36  // Track dynamic height
    let userProfilePhotoUrl: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Profile photo (bigger for prominence)
            CachedAsyncImage(url: URL(string: userProfilePhotoUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(AppColors.textTertiary.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColors.textTertiary.opacity(0.6))
                            .font(.system(size: 20))
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // Oval text field capsule (grows with content)
            HStack(alignment: .bottom, spacing: 8) {
                FocusableTextView(
                    text: $viewModel.newCommentText,
                    placeholder: viewModel.replyingTo != nil
                        ? "Replying to @\(viewModel.replyingTo?.authorNickname ?? "user")"
                        : "Join the conversation...",
                    font: UIFont.systemFont(ofSize: 15),
                    shouldFocus: isCommentFocused,
                    onFocusChange: { focused in
                        if focused {
                            inputState = .active
                        } else {
                            // Save draft on blur
                            viewModel.commentDraft = viewModel.newCommentText
                            inputState = viewModel.hasDraft ? .draft : .resting
                        }
                    },
                    onHeightChange: { newHeight in
                        // Only animate when height actually changes
                        if newHeight != self.dynamicHeight {
                            withAnimation(.easeInOut(duration: 0.08)) {
                                self.dynamicHeight = newHeight
                            }
                        }
                    }
                )
                .frame(height: dynamicHeight)  // Now dynamic!

                // Right button (Clear or Post)
                if inputState == .draft && !isCommentFocused {
                    // Clear button when draft exists and not focused
                    Button {
                        viewModel.commentDraft = ""
                        viewModel.newCommentText = ""
                        inputState = .resting
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.system(size: 22))
                    }
                    .padding(.bottom, 4)
                } else if inputState == .active || viewModel.canSubmitComment {
                    // Post button (up arrow icon like IG)
                    Button {
                        Task {
                            await viewModel.submitComment()
                            inputState = .resting
                            isCommentFocused = false
                        }
                    } label: {
                        if viewModel.isSubmittingComment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(viewModel.canSubmitComment ? AppColors.primary : AppColors.textTertiary)
                        }
                    }
                    .disabled(!viewModel.canSubmitComment)
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, 8)
        .background(AppColors.surface.ignoresSafeArea(edges: .bottom))
        .onChange(of: inputState) { _, newState in
            if newState == .active {
                // Load draft when becoming active
                if viewModel.hasDraft && viewModel.newCommentText.isEmpty {
                    viewModel.newCommentText = viewModel.commentDraft
                }
                isCommentFocused = true
            }
        }
        .onTapGesture {
            // Tap anywhere on bar to focus (if not already active)
            if inputState != .active {
                inputState = .active
            }
        }
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: Comment
    let postAuthorUid: String
    let isAuthor: Bool
    let onReply: () -> Void
    let onDelete: () -> Void
    let onDeleteReply: (Comment) -> Void
    let onAuthorTap: (String) -> Void

    @State private var showDeleteConfirmation = false
    @State private var showReplies = true
    @State private var replyToDelete: Comment?

    private var replyCount: Int {
        comment.replies?.count ?? 0
    }

    private var isPostAuthor: Bool {
        comment.authorUid == postAuthorUid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main comment
            mainCommentView
            
            // Nested replies with toggle
            if replyCount > 0 {
                repliesSection
            }
        }
        .alert("Delete Comment?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Reply?", isPresented: .constant(replyToDelete != nil)) {
            Button("Delete", role: .destructive) {
                if let reply = replyToDelete {
                    onDeleteReply(reply)
                    replyToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                replyToDelete = nil
            }
        }
    }
    
    // MARK: - Main Comment

    private var mainCommentView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header with author info
            HStack(spacing: AppSpacing.sm) {
                // Avatar (tappable)
                Button {
                    onAuthorTap(comment.authorUid)
                } label: {
                    avatarView(c: comment, size: 32)
                }
                .buttonStyle(.plain)

                // Author name with red dot if post author
                HStack(spacing: 4) {
                    Button {
                        onAuthorTap(comment.authorUid)
                    } label: {
                        Text(comment.authorNickname ?? "Unknown")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    if isPostAuthor {
                        Text("*")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.error)
                    }
                }

                Spacer()

                // Delete button for author
                if isAuthor {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            // Comment text
            Text(comment.displayText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AppSpacing.sm)

            // Footer: time, like, reply
            HStack(spacing: AppSpacing.md) {
                Text(comment.timeAgoString)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)

                Button {
                    // TODO: Implement comment likes
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

                        Text("Like")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Button {
                    onReply()
                } label: {
                    Text("Reply")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.contentPadding)
    }

    // MARK: - Replies Section

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Replies list
            if let replies = comment.replies {
                ForEach(replies) { reply in
                    replyView(reply)

                    // Separator between replies
                    if reply.id != replies.last?.id {
                        Rectangle()
                            .fill(AppColors.textTertiary.opacity(0.15))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Reply View (nested comment)

    private func replyView(_ reply: Comment) -> some View {
        let isReplyPostAuthor = reply.authorUid == postAuthorUid
        let isReplyAuthor = reply.authorUid == comment.authorUid || isAuthor

        return ZStack {
            // Grey background filling full width
            AppColors.backgroundSecondary.opacity(0.7)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header with author info
                HStack(spacing: AppSpacing.sm) {
                    // Avatar (tappable)
                    Button {
                        onAuthorTap(reply.authorUid)
                    } label: {
                        avatarView(c: reply, size: 32)
                    }
                    .buttonStyle(.plain)

                    // Author name with red dot if post author
                    HStack(spacing: 4) {
                        Button {
                            onAuthorTap(reply.authorUid)
                        } label: {
                            Text(reply.authorNickname ?? "Unknown")
                                .font(AppTypography.labelMedium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(.plain)

                        if isReplyPostAuthor {
                            Text("*")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.error)
                        }
                    }

                    Spacer()

                    // Delete button for author
                    if isReplyAuthor {
                        Button {
                            replyToDelete = reply
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                // Reply text
                Text(reply.displayText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, AppSpacing.sm)

                // Footer: time, like, reply
                HStack(spacing: AppSpacing.md) {
                    Text(reply.timeAgoString)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)

                    Button {
                        // TODO: Implement comment likes
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)

                            Text("Like")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Button {
                        onReply()
                    } label: {
                        Text("Reply")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.leading, AppSpacing.contentPadding + AppSpacing.lg)
            .padding(.trailing, AppSpacing.contentPadding)
        }
    }
    
    // MARK: - Avatar Helper
    
    private func avatarView(c: Comment, size: CGFloat) -> some View {
        Group {
            if let photoUrl = c.authorPhotoUrl, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(AppColors.backgroundSecondary)
                }
            } else {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .overlay(
                        Text(String(c.authorNickname?.prefix(1) ?? "?"))
                            .font(size > 30 ? AppTypography.bodyMedium : AppTypography.caption)
                            .foregroundColor(AppColors.primary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Rounded Corner Shape

struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Focusable TextView Wrapper

/// SwiftUI wrapper for text input with external focus control
struct FocusableTextView: View {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let shouldFocus: Bool
    let onFocusChange: ((Bool) -> Void)?
    let onHeightChange: ((CGFloat) -> Void)?

    init(
        text: Binding<String>,
        placeholder: String,
        font: UIFont,
        shouldFocus: Bool,
        onFocusChange: ((Bool) -> Void)? = nil,
        onHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.shouldFocus = shouldFocus
        self.onFocusChange = onFocusChange
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        UIKitTextView(
            text: $text,
            placeholder: placeholder,
            font: font,
            shouldFocus: shouldFocus,
            onFocusChange: onFocusChange,
            onHeightChange: onHeightChange ?? { _ in }
        )
        .onChange(of: shouldFocus) { _, newValue in
            // Handle focus changes outside the view update cycle
            if newValue {
                NotificationCenter.default.post(name: .focusCommentTextField, object: nil)
            }
        }
    }
}

extension NSNotification.Name {
    static let focusCommentTextField = NSNotification.Name("focusCommentTextField")
}

// MARK: - UIKit TextView Wrapper

/// UIKit TextView wrapper with focus change callback.
struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let shouldFocus: Bool
    let onFocusChange: ((Bool) -> Void)?
    let onHeightChange: (CGFloat) -> Void

    init(text: Binding<String>, placeholder: String, font: UIFont, shouldFocus: Bool = false, onFocusChange: ((Bool) -> Void)? = nil, onHeightChange: @escaping (CGFloat) -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.shouldFocus = shouldFocus
        self.onFocusChange = onFocusChange
        self.onHeightChange = onHeightChange
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.delegate = context.coordinator
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.isScrollEnabled = false  // Start disabled, enable dynamically when content exceeds 150pt
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Ensure it can become first responder immediately
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Add notification observer for focus requests
        context.coordinator.setupNotificationObserver(for: textView)

        // Pre-warm responder if needed - triggers keyboard immediately
        if shouldFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        // Update height if needed (with safeguards)
        context.coordinator.updateHeightIfNeeded(uiView)

        // Update placeholder visibility
        context.coordinator.updatePlaceholder(in: uiView)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.removeNotificationObserver()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, onFocusChange: onFocusChange, onHeightChange: onHeightChange)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let placeholder: String
        let onFocusChange: ((Bool) -> Void)?
        let onHeightChange: (CGFloat) -> Void
        private var placeholderLabel: UILabel?
        weak var textView: UITextView?
        private var notificationObserver: NSObjectProtocol?
        private var lastReportedHeight: CGFloat = 36  // Track last height to prevent loops

        init(text: Binding<String>, placeholder: String, onFocusChange: ((Bool) -> Void)?, onHeightChange: @escaping (CGFloat) -> Void) {
            _text = text
            self.placeholder = placeholder
            self.onFocusChange = onFocusChange
            self.onHeightChange = onHeightChange
        }

        func setupNotificationObserver(for textView: UITextView) {
            self.textView = textView
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .focusCommentTextField,
                object: nil,
                queue: .main
            ) { [weak textView] _ in
                textView?.becomeFirstResponder()
            }
        }

        func removeNotificationObserver() {
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onFocusChange?(true)
            // Update placeholder visibility based on text content
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            onFocusChange?(false)
            // Restore placeholder visibility if text is empty
            updatePlaceholder(in: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            updateHeightIfNeeded(textView)
            updatePlaceholder(in: textView)
        }

        func updateHeightIfNeeded(_ textView: UITextView) {
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
            // Clamp between 36pt (1 line) and 120pt (~5 lines)
            let newHeight = min(max(36, size.height), 120)

            // Only report if height changed significantly (1pt threshold to avoid jitter)
            if abs(newHeight - lastReportedHeight) > 1.0 {
                lastReportedHeight = newHeight
                onHeightChange(newHeight)
            }

            // Enable scrolling ONLY when we hit max height (immediate, not async)
            textView.isScrollEnabled = size.height > 120
        }

        func updatePlaceholder(in textView: UITextView) {
            // Create placeholder label if needed
            if placeholderLabel == nil {
                let label = UILabel()
                label.text = placeholder
                label.font = textView.font
                label.textColor = UIColor.placeholderText
                label.numberOfLines = 0
                label.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(label)

                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -8),
                    label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
                ])

                placeholderLabel = label
            }

            // Show/hide placeholder
            placeholderLabel?.isHidden = !textView.text.isEmpty
        }
    }
}

