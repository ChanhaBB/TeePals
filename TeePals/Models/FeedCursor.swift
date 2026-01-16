import Foundation

/// Pagination cursor for Friends Feed (time-based)
struct FriendsFeedCursor: Codable {
    let lastCreatedAt: Date
    let lastPostId: String
}

/// Pagination cursor for Public Feed (bucket-based)
struct PublicFeedCursor: Codable {
    let dateKey: String  // YYYY-MM-DD for deterministic seeding
    let recentOffset: Int
    let trendingOffset: Int
    let newCreatorsOffset: Int
    let seenPostIds: [String]  // Small list for dedupe

    init(
        dateKey: String = Self.todayKey(),
        recentOffset: Int = 0,
        trendingOffset: Int = 0,
        newCreatorsOffset: Int = 0,
        seenPostIds: [String] = []
    ) {
        self.dateKey = dateKey
        self.recentOffset = recentOffset
        self.trendingOffset = trendingOffset
        self.newCreatorsOffset = newCreatorsOffset
        self.seenPostIds = seenPostIds
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

/// Bucket type for Public Feed
enum FeedBucket {
    case recent
    case trending
    case newCreators
}
