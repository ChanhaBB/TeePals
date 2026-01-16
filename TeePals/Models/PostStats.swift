import Foundation

/// Aggregate statistics for a post, maintained by Cloud Functions.
/// Used for ranking and trending calculations.
struct PostStats: Codable, Identifiable {
    var id: String { postId }

    let postId: String
    var upvoteCount: Int
    var commentCount: Int
    var lastEngagementAt: Date
    var hotScore7d: Double
    var updatedAt: Date

    init(
        postId: String,
        upvoteCount: Int = 0,
        commentCount: Int = 0,
        lastEngagementAt: Date = Date(),
        hotScore7d: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.postId = postId
        self.upvoteCount = upvoteCount
        self.commentCount = commentCount
        self.lastEngagementAt = lastEngagementAt
        self.hotScore7d = hotScore7d
        self.updatedAt = updatedAt
    }
}
