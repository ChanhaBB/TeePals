import Foundation

/// ViewModel for viewing and interacting with a single post.
/// Handles upvoting, editing, deleting, and comment management.
@MainActor
final class PostDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let postsRepository: PostsRepository
    private let roundsRepository: RoundsRepository
    private let currentUid: () -> String?
    
    // MARK: - State
    
    let postId: String
    @Published var post: Post?
    @Published var linkedRound: Round?
    @Published var comments: [Comment] = []
    @Published var commentTree: [Comment] = []
    
    @Published var isLoading = false
    @Published var isLoadingComments = false
    @Published var errorMessage: String?
    
    // Edit mode
    @Published var isEditing = false
    @Published var editText: String = ""
    @Published var isSaving = false
    
    // Delete confirmation
    @Published var isShowingDeleteConfirmation = false
    @Published var isDeleting = false
    
    // Comment composer
    @Published var newCommentText: String = ""
    @Published var commentDraft: String = ""  // Persists within this post only
    @Published var replyingTo: Comment?
    @Published var isSubmittingComment = false
    
    // MARK: - Init
    
    init(
        postId: String,
        postsRepository: PostsRepository,
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.postId = postId
        self.postsRepository = postsRepository
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Callbacks

    var onPostUpdated: ((Post) -> Void)?

    // MARK: - Computed

    var uid: String? { currentUid() }

    var isAuthor: Bool {
        guard let uid = currentUid(), let post = post else { return false }
        return post.authorUid == uid
    }

    var canSubmitComment: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmittingComment
    }

    var hasDraft: Bool {
        !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Load Post
    
    func loadPost() async {
        isLoading = true
        errorMessage = nil
        
        do {
            post = try await postsRepository.fetchPost(id: postId)
            
            // Load linked round if present
            if let roundId = post?.linkedRoundId {
                linkedRound = try await roundsRepository.fetchRound(id: roundId)
            }
            
            // Load comments
            await loadComments()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Load Comments

    func loadComments() async {
        isLoadingComments = true

        do {
            let fetchedComments = try await postsRepository.fetchComments(postId: postId)
            comments = fetchedComments
            commentTree = fetchedComments.buildCommentTree()
        } catch {
            print("Failed to load comments: \(error)")
        }

        isLoadingComments = false
    }

    // MARK: - Refresh

    func refresh() async {
        // Reload post and comments silently (no loading state)
        do {
            post = try await postsRepository.fetchPost(id: postId)

            // Reload linked round if present
            if let roundId = post?.linkedRoundId {
                linkedRound = try await roundsRepository.fetchRound(id: roundId)
            }

            // Reload comments
            let fetchedComments = try await postsRepository.fetchComments(postId: postId)
            comments = fetchedComments
            commentTree = fetchedComments.buildCommentTree()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Upvote

    func toggleUpvote() async {
        guard let post = post else { return }

        // Optimistic update
        let wasUpvoted = post.hasUpvoted ?? false
        self.post?.hasUpvoted = !wasUpvoted
        // Never let count go below 0
        let delta = wasUpvoted ? -1 : 1
        if let currentCount = self.post?.upvoteCount {
            self.post?.upvoteCount = max(0, currentCount + delta)
        }

        do {
            // Returns true if upvoted, false if removed
            // Count will be updated asynchronously by Cloud Function
            _ = try await postsRepository.toggleUpvote(postId: postId)
        } catch {
            // Revert on error
            self.post?.hasUpvoted = wasUpvoted
            // Never let count go below 0 on revert either
            let revertDelta = wasUpvoted ? 1 : -1
            if let currentCount = self.post?.upvoteCount {
                self.post?.upvoteCount = max(0, currentCount + revertDelta)
            }
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Edit Post
    
    func startEditing() {
        guard let post = post else { return }
        editText = post.text
        isEditing = true
    }
    
    func cancelEditing() {
        isEditing = false
        editText = ""
    }
    
    func saveEdit() async {
        guard var updatedPost = post else { return }
        
        isSaving = true
        updatedPost.text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPost.isEdited = true
        
        do {
            try await postsRepository.updatePost(updatedPost)
            post = updatedPost
            isEditing = false
            editText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Post
    
    func deletePost() async -> Bool {
        isDeleting = true
        
        do {
            try await postsRepository.deletePost(id: postId)
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
    
    // MARK: - Comments
    
    func setReplyTarget(_ comment: Comment?) {
        replyingTo = comment
        if comment != nil {
            // Pre-fill @mention for nested replies
            if comment?.depth == Comment.maxDepth {
                newCommentText = "@\(comment?.authorNickname ?? "") "
            }
        }
    }
    
    func submitComment() async {
        guard canSubmitComment, let uid = currentUid() else { return }
        
        isSubmittingComment = true
        
        // Determine parent and depth
        var parentId: String?
        var depth = 0
        var replyToUid: String?
        var replyToNickname: String?
        
        if let reply = replyingTo {
            if reply.depth == 0 {
                // Replying to top-level comment -> depth 1
                parentId = reply.id
                depth = 1
            } else {
                // Replying to nested comment -> flat with @mention
                parentId = reply.parentCommentId
                depth = 1
                replyToUid = reply.authorUid
                replyToNickname = reply.authorNickname
            }
        }
        
        let comment = Comment(
            postId: postId,
            authorUid: uid,
            text: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines),
            parentCommentId: parentId,
            replyToUid: replyToUid,
            replyToNickname: replyToNickname,
            depth: depth
        )
        
        do {
            let createdComment = try await postsRepository.createComment(comment)

            // Optimistic update: Replace arrays entirely (SwiftUI detects new references)
            let newComments = comments + [createdComment]
            comments = newComments
            commentTree = newComments.buildCommentTree()

            // NOTE: commentCount is incremented in Firestore by the repository
            // We don't need to update it locally - it will be correct when we reload

            // Reset
            newCommentText = ""
            commentDraft = ""  // Clear draft on successful submit
            replyingTo = nil

        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmittingComment = false
    }
    
    func deleteComment(_ comment: Comment) async {
        guard let commentId = comment.id else { return }

        do {
            try await postsRepository.deleteComment(postId: postId, commentId: commentId)

            // Optimistic update: Replace arrays entirely (SwiftUI detects new references)
            let newComments = comments.filter { $0.id != commentId }
            comments = newComments
            commentTree = newComments.buildCommentTree()

            // NOTE: commentCount is decremented in Firestore by the repository
            // We don't need to update it locally - it will be correct when we reload

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCommentLike(_ comment: Comment) async {
        guard let commentId = comment.id else { return }

        // Optimistic update
        let wasLiked = comment.hasLiked ?? false
        if let index = comments.firstIndex(where: { $0.id == commentId }) {
            comments[index].hasLiked = !wasLiked
            let delta = wasLiked ? -1 : 1
            if let currentCount = comments[index].likeCount {
                comments[index].likeCount = max(0, currentCount + delta)
            }

            // Rebuild tree to reflect changes
            commentTree = comments.buildCommentTree()
        }

        do {
            _ = try await postsRepository.toggleCommentLike(postId: postId, commentId: commentId)
        } catch {
            // Revert on error
            if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index].hasLiked = wasLiked
                let revertDelta = wasLiked ? 1 : -1
                if let currentCount = comments[index].likeCount {
                    comments[index].likeCount = max(0, currentCount + revertDelta)
                }
                commentTree = comments.buildCommentTree()
            }
            errorMessage = error.localizedDescription
        }
    }
}





