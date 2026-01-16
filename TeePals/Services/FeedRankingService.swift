import Foundation
import CryptoKit

/// Service for feed ranking, scoring, and mixing.
/// Implements client-side deterministic ranking algorithm.
final class FeedRankingService {

    private let config: FeedRankingConfig

    init(config: FeedRankingConfig = .shared) {
        self.config = config
    }

    // MARK: - Scoring

    /// Compute feed score for a post
    func computeScore(
        viewerContext: ViewerContext,
        post: Post,
        postStats: PostStats,
        authorStats: UserStats,
        isFriendsFeed: Bool
    ) -> FeedScore {
        // 1. Time decay (strongest signal)
        let ageHours = Date().timeIntervalSince(post.createdAt) / 3600
        let halfLife = isFriendsFeed ? config.friendsHalfLifeHours : config.publicHalfLifeHours
        let timeScore = exp(-ageHours / halfLife)

        // 2. Engagement boost (bounded, logarithmic)
        let engagement = postStats.upvoteCount + 2 * postStats.commentCount
        let engagementBoost = min(
            config.maxEngagementBoost,
            config.engagementWeight * log(1 + Double(engagement))
        )

        // 3. New author boost (fairness)
        let newAuthorBoost = authorStats.isNewAuthor ? config.newAuthorBoostValue : 0.0

        // 4. Geo boost (soft personalization)
        let geoBoost = (post.cityId == viewerContext.cityId && post.cityId != nil) ? config.sameCityBoost : 0.0

        // 5. Course boost (soft personalization)
        let courseBoost = (post.courseId == viewerContext.homeCourseId && post.courseId != nil) ? config.sameCourseBoost : 0.0

        // 6. Tag boost (soft personalization)
        let tagOverlap = Set(post.tags ?? []).intersection(Set(viewerContext.interests))
        let rawTagBoost = config.tagBoost * Double(tagOverlap.count)
        let tagBoost = min(rawTagBoost, config.maxTagBoost)

        let total = timeScore + engagementBoost + newAuthorBoost + geoBoost + courseBoost + tagBoost

        let breakdown = FeedScoreBreakdown(
            time: timeScore,
            engagement: engagementBoost,
            newAuthor: newAuthorBoost,
            geo: geoBoost,
            course: courseBoost,
            tags: tagBoost
        )

        return FeedScore(total: total, breakdown: breakdown)
    }

    // MARK: - Sorting & Diversity

    /// Sort posts by score (descending), then createdAt (descending), then postId
    func sortByScore(_ scoredPosts: [ScoredPost]) -> [ScoredPost] {
        return scoredPosts.sorted { lhs, rhs in
            if lhs.score.total != rhs.score.total {
                return lhs.score.total > rhs.score.total
            }
            if lhs.post.createdAt != rhs.post.createdAt {
                return lhs.post.createdAt > rhs.post.createdAt
            }
            return (lhs.post.id ?? "") > (rhs.post.id ?? "")
        }
    }

    /// Enforce diversity: max N consecutive posts from same author
    func enforceDiversity(_ scoredPosts: [ScoredPost]) -> [ScoredPost] {
        guard config.maxConsecutiveSameAuthor > 0 else { return scoredPosts }

        var result: [ScoredPost] = []
        var pending: [ScoredPost] = scoredPosts
        var lastAuthorUid: String?
        var consecutiveCount = 0

        while !pending.isEmpty {
            var foundDifferent = false

            // Try to find next post from different author
            for (index, scoredPost) in pending.enumerated() {
                let authorUid = scoredPost.post.authorUid

                if authorUid != lastAuthorUid {
                    // Different author, safe to add
                    result.append(scoredPost)
                    pending.remove(at: index)
                    lastAuthorUid = authorUid
                    consecutiveCount = 1
                    foundDifferent = true
                    break
                } else if consecutiveCount < config.maxConsecutiveSameAuthor {
                    // Same author but still within limit
                    result.append(scoredPost)
                    pending.remove(at: index)
                    consecutiveCount += 1
                    foundDifferent = true
                    break
                }
            }

            // If we couldn't find a different author, reset and continue
            if !foundDifferent {
                if let firstPending = pending.first {
                    result.append(firstPending)
                    pending.removeFirst()
                    lastAuthorUid = firstPending.post.authorUid
                    consecutiveCount = 1
                }
            }
        }

        return result
    }

    // MARK: - Bucket Mixing (Public Feed)

    /// Interleave posts from multiple buckets using deterministic pattern
    func interleaveBuckets(
        recent: [ScoredPost],
        trending: [ScoredPost],
        newCreators: [ScoredPost],
        seed: Int,
        count: Int
    ) -> [ScoredPost] {
        var result: [ScoredPost] = []
        var recentIndex = 0
        var trendingIndex = 0
        var newCreatorsIndex = 0

        let pattern: [FeedBucket] = [
            .recent, .recent, .recent,
            .trending,
            .recent, .recent,
            .newCreators,
            .recent,
            .trending,
            .newCreators
        ]

        var patternIndex = seed % pattern.count
        var hardInjectionCounter = 0

        while result.count < count {
            // Hard injection rule: every K posts, force inject new creator if available
            hardInjectionCounter += 1
            if hardInjectionCounter >= config.injectionIntervalK && newCreatorsIndex < newCreators.count {
                result.append(newCreators[newCreatorsIndex])
                newCreatorsIndex += 1
                hardInjectionCounter = 0
                continue
            }

            // Follow pattern
            let bucket = pattern[patternIndex]
            patternIndex = (patternIndex + 1) % pattern.count

            var addedFromBucket = false

            switch bucket {
            case .recent:
                if recentIndex < recent.count {
                    result.append(recent[recentIndex])
                    recentIndex += 1
                    addedFromBucket = true
                }
            case .trending:
                if trendingIndex < trending.count {
                    result.append(trending[trendingIndex])
                    trendingIndex += 1
                    addedFromBucket = true
                }
            case .newCreators:
                if newCreatorsIndex < newCreators.count {
                    result.append(newCreators[newCreatorsIndex])
                    newCreatorsIndex += 1
                    addedFromBucket = true
                }
            }

            // If couldn't add from intended bucket, try others
            if !addedFromBucket {
                if recentIndex < recent.count {
                    result.append(recent[recentIndex])
                    recentIndex += 1
                } else if trendingIndex < trending.count {
                    result.append(trending[trendingIndex])
                    trendingIndex += 1
                } else if newCreatorsIndex < newCreators.count {
                    result.append(newCreators[newCreatorsIndex])
                    newCreatorsIndex += 1
                } else {
                    // No more posts in any bucket
                    break
                }
            }
        }

        return result
    }

    /// Generate deterministic seed from viewerId and date
    func generateSeed(viewerId: String, dateKey: String) -> Int {
        let input = "\(viewerId)_\(dateKey)"
        let hash = SHA256.hash(data: Data(input.utf8))
        let hashInt = hash.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        return abs(hashInt)
    }

    // MARK: - Deduplication

    /// Remove posts that have already been seen
    func deduplicate(_ posts: [Post], seen: Set<String>) -> [Post] {
        return posts.filter { post in
            guard let postId = post.id else { return false }
            return !seen.contains(postId)
        }
    }

    /// Remove duplicate posts by ID
    func deduplicateById(_ posts: [Post]) -> [Post] {
        var seen = Set<String>()
        var result: [Post] = []

        for post in posts {
            guard let postId = post.id else { continue }
            if !seen.contains(postId) {
                seen.insert(postId)
                result.append(post)
            }
        }

        return result
    }
}
