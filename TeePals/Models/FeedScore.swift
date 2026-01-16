import Foundation

/// Feed ranking score for a post
struct FeedScore {
    let total: Double
    let breakdown: FeedScoreBreakdown
}

/// Breakdown of score components for debugging and explainability
struct FeedScoreBreakdown {
    let time: Double
    let engagement: Double
    let newAuthor: Double
    let geo: Double
    let course: Double
    let tags: Double

    var description: String {
        """
        Time: \(String(format: "%.2f", time))
        Engagement: \(String(format: "%.2f", engagement))
        New Author: \(String(format: "%.2f", newAuthor))
        Geo: \(String(format: "%.2f", geo))
        Course: \(String(format: "%.2f", course))
        Tags: \(String(format: "%.2f", tags))
        ---
        Total: \(String(format: "%.2f", time + engagement + newAuthor + geo + course + tags))
        """
    }
}

/// Post with computed score for feed ranking
struct ScoredPost {
    let post: Post
    let score: FeedScore
}
