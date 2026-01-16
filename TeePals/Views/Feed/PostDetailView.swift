import SwiftUI

/// Detail view for a single post with comments.
/// Supports upvoting, editing, deleting, and nested comments.
struct PostDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppContainer
    @StateObject private var viewModel: PostDetailViewModel
    @FocusState private var isCommentFocused: Bool

    @State private var selectedAuthorUid: String?
    @State private var selectedRoundId: String?

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
            AppColors.backgroundGrouped
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
            } else if let post = viewModel.post {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // Post content
                            postContent(post)
                            
                            Divider()
                            
                            // Comments section
                            commentsSection
                        }
                        .padding(AppSpacing.contentPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                
                // Comment composer
                VStack(spacing: 0) {
                    Spacer()
                    commentComposer
                }
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(AppColors.error)
                    Button("Retry") {
                        Task { await viewModel.loadPost() }
                    }
                }
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isAuthor {
                    authorMenu
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
        .onAppear {
            // Wire up the callback
            viewModel.onPostUpdated = onUpdated
        }
        .onChange(of: viewModel.replyingTo) { _, newValue in
            // Focus keyboard when user taps reply
            if newValue != nil {
                isCommentFocused = true
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
    }
    
    // MARK: - Author Menu
    
    private var authorMenu: some View {
        Menu {
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
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Post Content
    
    private func postContent(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
            }
            
            // Linked round
            if let round = viewModel.linkedRound {
                linkedRoundCard(round)
            }
            
            // Interactions
            interactionsBar(post)
        }
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
                ForEach(urls, id: \.self) { url in
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
        HStack(spacing: AppSpacing.lg) {
            // Upvote
            Button {
                Task {
                    await viewModel.toggleUpvote()
                    // Notify parent view of upvote change
                    if let updatedPost = viewModel.post {
                        onUpdated(updatedPost)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: post.hasUpvoted == true ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.title3)
                        .foregroundColor(post.hasUpvoted == true ? AppColors.primary : AppColors.textSecondary)

                    Text("\(post.upvoteCount)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(post.hasUpvoted == true ? AppColors.primary : AppColors.textSecondary)
                }
            }
            
            // Comments count
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
                
                Text("\(post.commentCount)")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.top, AppSpacing.sm)
    }
    
    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Comments")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            if viewModel.isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.commentTree.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                ForEach(viewModel.commentTree) { comment in
                    CommentRowView(
                        comment: comment,
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
                }
            }

            // Spacer for keyboard
            Spacer(minLength: 80)
        }
    }
    
    // MARK: - Comment Composer
    
    private var commentComposer: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: AppSpacing.xs) {
                // Reply indicator
                if let replyTo = viewModel.replyingTo {
                    HStack {
                        Text("Replying to @\(replyTo.authorNickname ?? "user")")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            viewModel.setReplyTarget(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)
                    .padding(.top, AppSpacing.xs)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    TextField("Add a comment...", text: $viewModel.newCommentText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isCommentFocused)
                    
                    Button {
                        Task {
                            await viewModel.submitComment()
                            isCommentFocused = false
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.canSubmitComment ? AppColors.primary : AppColors.textTertiary)
                    }
                    .disabled(!viewModel.canSubmitComment)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.sm)
            }
            .background(AppColors.backgroundPrimary)
        }
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: Comment
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
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Avatar (tappable)
            Button {
                onAuthorTap(comment.authorUid)
            } label: {
                avatarView(c: comment, size: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Header: name, time, edited
                HStack(spacing: 4) {
                    Button {
                        onAuthorTap(comment.authorUid)
                    } label: {
                        Text(comment.authorNickname ?? "Unknown")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(comment.timeAgoString)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                    
                    if comment.isEdited {
                        Text("· edited")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // Comment text
                Text(comment.displayText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                HStack(spacing: AppSpacing.lg) {
                    Button {
                        onReply()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.caption)
                            Text("Reply")
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if isAuthor {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.error.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Replies Section
    
    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showReplies.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    // Connecting line
                    Rectangle()
                        .fill(AppColors.primary.opacity(0.3))
                        .frame(width: 2, height: 16)
                        .padding(.leading, 17) // Align with avatar center
                    
                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(AppColors.primary)
                    
                    Text(showReplies ? "Hide \(replyCount) \(replyCount == 1 ? "reply" : "replies")" : "View \(replyCount) \(replyCount == 1 ? "reply" : "replies")")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.vertical, AppSpacing.xs)
            
            // Replies list
            if showReplies, let replies = comment.replies {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(replies) { reply in
                        replyView(reply)
                    }
                }
            }
        }
    }
    
    // MARK: - Reply View (nested comment)
    
    private func replyView(_ reply: Comment) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Connecting line + avatar
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 2)
                    .padding(.leading, 17) // Align with parent avatar center

                Spacer()
                    .frame(width: AppSpacing.sm)

                Button {
                    onAuthorTap(reply.authorUid)
                } label: {
                    avatarView(c: reply, size: 28)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Header
                HStack(spacing: 4) {
                    Button {
                        onAuthorTap(reply.authorUid)
                    } label: {
                        Text(reply.authorNickname ?? "Unknown")
                            .font(AppTypography.captionEmphasis)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(reply.timeAgoString)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // Reply text with @mention styling
                Text(reply.displayText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions for reply
                HStack(spacing: AppSpacing.lg) {
                    Button {
                        onReply()
                    } label: {
                        Text("Reply")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if reply.authorUid == comment.authorUid || isAuthor {
                        Button {
                            replyToDelete = reply
                        } label: {
                            Text("Delete")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.error.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xs)
        .background(
            AppColors.backgroundSecondary.opacity(0.3)
                .cornerRadius(AppSpacing.sm)
                .padding(.leading, AppSpacing.xl)
        )
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

