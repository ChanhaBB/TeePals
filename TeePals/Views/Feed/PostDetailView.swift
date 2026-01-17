import SwiftUI
import PhotosUI

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
    @State private var isComposingComment = false
    @State private var selectedCommentPhoto: PhotosPickerItem?
    @State private var commentPhotoImage: UIImage?
    @FocusState private var isCommentFocused: Bool
    @State private var composerHeight: CGFloat = 80  // Default collapsed height

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
    
    var body: some View {
        ZStack {
            // White background extending to top
            AppColors.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom navigation bar
                customNavigationBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let post = viewModel.post {
                    ZStack(alignment: .bottom) {
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

                                // Bottom padding for composer
                                Color.clear.frame(height: composerHeight)
                            }
                        }
                        .scrollDisabled(isCommentFocused)  // Disable scroll when focused
                        .scrollDismissesKeyboard(.interactively)
                        .refreshable {
                            await viewModel.refresh()
                        }
                        .background(AppColors.backgroundGrouped)

                        // Comment composer (overlaid at bottom, outside scroll hierarchy)
                        commentComposer
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
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .onChange(of: viewModel.replyingTo) { _, newValue in
            // Show composer when user taps reply
            if newValue != nil {
                isComposingComment = true
                isCommentFocused = true
            }
        }
        .onChange(of: selectedCommentPhoto) { _, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    commentPhotoImage = image
                }
            }
        }
        .onChange(of: isCommentFocused) { _, newValue in
            // Sync composing state with focus
            if newValue {
                isComposingComment = true
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
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
    }
    
    // MARK: - Comment Composer

    private var commentComposer: some View {
        // Two-layer structure: unclipped background + clipped content
        ZStack(alignment: .top) {
            // Layer 1: Full safe-area background (NOT clipped)
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)  // Just to establish layout
                AppColors.surface
                    .ignoresSafeArea(edges: .bottom)
            }

            // Layer 2: Content with rounded corners (clipped, on top)
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, AppSpacing.sm)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Dismiss if swiped down
                                if value.translation.height > 50 {
                                    viewModel.newCommentText = ""
                                    viewModel.setReplyTarget(nil)
                                    isComposingComment = false
                                    isCommentFocused = false
                                    commentPhotoImage = nil
                                    selectedCommentPhoto = nil
                                }
                            }
                    )

                // Text input area
                if !isComposingComment {
                    // Collapsed state - entire row tappable
                    HStack {
                        Text("Add a comment")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.setReplyTarget(nil)
                        isComposingComment = true
                        isCommentFocused = true
                    }
                } else {
                    // Expanded state - native TextEditor
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.newCommentText)
                            .font(.system(size: 16))
                            .frame(minHeight: 100, maxHeight: 150)
                            .scrollContentBackground(.hidden)
                            .focused($isCommentFocused)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)

                        // Placeholder overlay
                        if viewModel.newCommentText.isEmpty {
                            Text(viewModel.replyingTo != nil
                                ? "Replying to @\(viewModel.replyingTo?.authorNickname ?? "user")"
                                : "Add a comment")
                                .font(.system(size: 16))
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.leading, 8)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)
                    .padding(.vertical, AppSpacing.sm)
                }

                // Photo preview (only show when image is loaded)
                if let photoImage = commentPhotoImage {
                    HStack {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))

                            Button {
                                commentPhotoImage = nil
                                selectedCommentPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 4, y: -4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)
                    .padding(.bottom, AppSpacing.sm)
                }

                // Action bar with photo and post button (only when composing)
                if isComposingComment {
                    HStack(spacing: AppSpacing.sm) {
                        // Photo picker
                        PhotosPicker(selection: $selectedCommentPhoto, matching: .images) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        // Post button
                        Button {
                            Task {
                                await viewModel.submitComment()
                                viewModel.newCommentText = ""
                                viewModel.setReplyTarget(nil)
                                isComposingComment = false
                                isCommentFocused = false
                                commentPhotoImage = nil
                                selectedCommentPhoto = nil
                            }
                        } label: {
                            Text("Post")
                                .font(AppTypography.labelLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.sm)
                                .background(viewModel.canSubmitComment ? AppColors.primary : AppColors.textTertiary)
                                .cornerRadius(AppSpacing.radiusMedium)
                        }
                        .disabled(!viewModel.canSubmitComment)
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)
                    .padding(.bottom, AppSpacing.sm)
                }
            }
            .background(AppColors.surface)
            .clipShape(
                RoundedCornerShape(corners: [.topLeft, .topRight], radius: AppSpacing.radiusLarge)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ComposerHeightPreferenceKey.self,
                        value: geometry.size.height
                    )
                }
            )
        }
        .onPreferenceChange(ComposerHeightPreferenceKey.self) { height in
            composerHeight = height
        }
    }
}

// MARK: - Preference Key for Composer Height

struct ComposerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 80
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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


