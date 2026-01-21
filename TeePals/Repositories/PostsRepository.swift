import Foundation

/// Protocol for posts and comments data access.
/// Abstracts Firestore implementation from ViewModels and Views.
protocol PostsRepository {
    
    // MARK: - Post CRUD
    
    /// Creates a new post and returns it with ID.
    func createPost(_ post: Post) async throws -> Post
    
    /// Fetches a single post by ID.
    func fetchPost(id: String) async throws -> Post?
    
    /// Updates an existing post (author only).
    func updatePost(_ post: Post) async throws
    
    /// Deletes a post (author only).
    func deletePost(id: String) async throws

    /// Updates denormalized author profile data on all posts by this user.
    /// Called when user updates their profile photo or nickname.
    func updateAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws

    /// Updates denormalized author profile data on all comments by this user.
    /// Called when user updates their profile photo or nickname.
    func updateCommentAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws

    // MARK: - Feed Queries (Legacy - kept for compatibility)

    /// Fetches feed posts for the current user.
    /// - Parameters:
    ///   - filter: all or friends-only
    ///   - limit: max posts to return
    ///   - after: pagination cursor (createdAt of last post)
    func fetchFeed(
        filter: FeedFilter,
        limit: Int,
        after: Date?
    ) async throws -> [Post]

    /// Fetches posts by a specific user.
    func fetchUserPosts(
        uid: String,
        limit: Int,
        after: Date?
    ) async throws -> [Post]

    // MARK: - Advanced Feed Queries (Phase 4.2)

    /// Fetches posts from specific authors (Friends Feed)
    /// - Parameters:
    ///   - authorUids: List of author UIDs (max 30 for Firestore IN query)
    ///   - windowStart: Start of time window
    ///   - limit: Max posts to return
    func fetchFriendsPostsCandidates(
        authorUids: [String],
        windowStart: Date,
        limit: Int
    ) async throws -> [Post]

    /// Fetches recent public posts (Recent Bucket)
    func fetchRecentPublicPosts(
        windowStart: Date,
        limit: Int
    ) async throws -> [Post]

    /// Fetches trending posts by hotScore7d (Trending Bucket)
    /// - Returns: Array of (postId, hotScore) tuples
    func fetchTrendingPostIds(
        limit: Int
    ) async throws -> [(String, Double)]

    /// Fetches posts by IDs (for Trending Bucket after hotScore query)
    func fetchPostsByIds(_ ids: [String]) async throws -> [Post]

    /// Fetches recent posts filtered by new authors (New Creators Bucket)
    func fetchNewCreatorsPosts(
        windowStart: Date,
        limit: Int
    ) async throws -> [Post]
    
    // MARK: - Upvotes

    /// Toggles upvote on a post.
    /// - Returns: True if upvoted, false if removed upvote
    func toggleUpvote(postId: String) async throws -> Bool
    
    /// Checks if current user has upvoted a post.
    func hasUpvoted(postId: String) async throws -> Bool
    
    // MARK: - Comments

    /// Creates a new comment on a post.
    func createComment(_ comment: Comment) async throws -> Comment

    /// Fetches comments for a post.
    func fetchComments(postId: String) async throws -> [Comment]

    /// Updates a comment (author only).
    func updateComment(_ comment: Comment) async throws

    /// Deletes a comment (author only).
    func deleteComment(postId: String, commentId: String) async throws

    // MARK: - Comment Likes

    /// Toggles like on a comment.
    /// - Returns: True if liked, false if unliked
    func toggleCommentLike(postId: String, commentId: String) async throws -> Bool

    /// Checks if current user has liked a comment.
    func hasLikedComment(postId: String, commentId: String) async throws -> Bool

    // MARK: - Stats (Phase 4.2)

    /// Fetches postStats for a single post
    func fetchPostStats(postId: String) async throws -> PostStats?

    /// Fetches postStats for multiple posts (batch)
    func fetchPostStatsBatch(postIds: [String]) async throws -> [String: PostStats]

    /// Fetches userStats for a single user
    func fetchUserStats(uid: String) async throws -> UserStats?

    /// Fetches userStats for multiple users (batch)
    func fetchUserStatsBatch(uids: [String]) async throws -> [String: UserStats]
}

// MARK: - Feed Constants

enum FeedConstants {
    static let defaultPageSize = 20
    static let maxPageSize = 50
}





