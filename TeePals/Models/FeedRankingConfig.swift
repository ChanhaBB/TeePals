import Foundation

/// Configuration for feed ranking algorithm.
/// All constants are tunable for experimentation.
struct FeedRankingConfig {

    // MARK: - Time Decay

    /// Half-life in hours for Friends Feed time decay
    let friendsHalfLifeHours: Double = 24.0

    /// Half-life in hours for Public Feed time decay
    let publicHalfLifeHours: Double = 18.0

    // MARK: - Engagement

    /// Weight multiplier for engagement boost
    let engagementWeight: Double = 0.3

    /// Maximum engagement boost to prevent viral dominance
    let maxEngagementBoost: Double = 2.0

    // MARK: - Personalization

    /// Boost for posts from same city as viewer
    let sameCityBoost: Double = 0.5

    /// Boost for posts from viewer's home course
    let sameCourseBoost: Double = 0.8

    /// Boost per overlapping tag
    let tagBoost: Double = 0.2

    /// Maximum tag boost (cap at 3 tags)
    let maxTagBoost: Double = 0.6

    // MARK: - Fairness

    /// Fixed boost value for new authors
    let newAuthorBoostValue: Double = 1.0

    /// Days threshold to qualify as new author
    let newAuthorDaysThreshold: Int = 30

    /// Post count threshold to qualify as new author
    let newAuthorPostCountThreshold: Int = 5

    // MARK: - Diversity

    /// Maximum consecutive posts from same author before enforcing diversity
    let maxConsecutiveSameAuthor: Int = 2

    // MARK: - Bucket Mixing (Public Feed)

    /// Weight for Recent bucket (60%)
    let recentBucketWeight: Double = 0.6

    /// Weight for Trending bucket (20%)
    let trendingBucketWeight: Double = 0.2

    /// Weight for New Creators bucket (20%)
    let newCreatorsBucketWeight: Double = 0.2

    /// Inject 1 new creator post every K posts
    let injectionIntervalK: Int = 5

    // MARK: - Query Limits

    /// Maximum posts to fetch per bucket
    let bucketFetchLimit: Int = 100

    /// Posts per page for pagination
    let feedPageSize: Int = 20

    // MARK: - Time Windows

    /// Primary time window in days (7 days)
    let primaryWindowDays: Int = 7

    /// Fallback window 1 in days (30 days)
    let fallbackWindow1Days: Int = 30

    /// Fallback window 2 in days (180 days)
    let fallbackWindow2Days: Int = 180

    // MARK: - Debug

    /// Enable detailed score explanations (dev builds only)
    let enableScoreExplanations: Bool = false

    // MARK: - Singleton

    static let shared = FeedRankingConfig()

    private init() {}
}
