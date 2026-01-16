import Foundation

/// User statistics for feed ranking, maintained by Cloud Functions.
/// Tracks author activity for new creator detection.
struct UserStats: Codable, Identifiable {
    var id: String { userId }

    let userId: String
    var accountCreatedAt: Date
    var postCount: Int
    var isNewAuthor: Bool
    var updatedAt: Date

    init(
        userId: String,
        accountCreatedAt: Date = Date(),
        postCount: Int = 0,
        isNewAuthor: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.accountCreatedAt = accountCreatedAt
        self.postCount = postCount
        self.isNewAuthor = isNewAuthor
        self.updatedAt = updatedAt
    }

    /// Recompute isNewAuthor based on account age and post count
    func computeIsNewAuthor(config: FeedRankingConfig) -> Bool {
        let accountAgeSeconds = Date().timeIntervalSince(accountCreatedAt)
        let accountAgeDays = accountAgeSeconds / (24 * 60 * 60)

        return accountAgeDays < Double(config.newAuthorDaysThreshold) ||
               postCount < config.newAuthorPostCountThreshold
    }
}
