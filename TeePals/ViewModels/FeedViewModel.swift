import Foundation

/// ViewModel for the social feed (Home tab).
/// Handles feed loading, filtering, and pull-to-refresh.
@MainActor
final class FeedViewModel: ObservableObject {
    
    // MARK: - Dependencies

    private let postsRepository: PostsRepository
    private let socialRepository: SocialRepository
    private let profileRepository: ProfileRepository
    private let roundsRepository: RoundsRepository
    private let currentUid: () -> String?
    private let rankingService: FeedRankingService
    private let config: FeedRankingConfig
    
    // MARK: - State

    @Published var posts: [Post] = []
    @Published var linkedRounds: [String: Round] = [:]
    @Published var filter: FeedFilter = .all
    @Published var isLoading = true // Start as true to show skeleton immediately
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    // Pagination (legacy)
    private var lastPostDate: Date?

    // Advanced ranking state (Phase 4.2)
    @Published var useAdvancedRanking = true  // Advanced ranking enabled
    private var friendsFeedCursor: FriendsFeedCursor?
    private var publicFeedCursor: PublicFeedCursor?
    private var seenPostIds: Set<String> = []
    private var viewerContext: ViewerContext?

    // MARK: - Init
    
    init(
        postsRepository: PostsRepository,
        socialRepository: SocialRepository,
        profileRepository: ProfileRepository,
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?,
        rankingService: FeedRankingService = FeedRankingService(),
        config: FeedRankingConfig = .shared
    ) {
        self.postsRepository = postsRepository
        self.socialRepository = socialRepository
        self.profileRepository = profileRepository
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
        self.rankingService = rankingService
        self.config = config
    }
    
    // MARK: - Computed

    var isEmpty: Bool { posts.isEmpty && !isLoading }
    var uid: String? { currentUid() }

    // MARK: - Helper Methods

    /// Fetches and hydrates linked rounds for posts
    private func loadLinkedRounds(for posts: [Post]) async {
        let roundIds = posts.compactMap { $0.linkedRoundId }.filter { linkedRounds[$0] == nil }
        guard !roundIds.isEmpty else { return }

        await withTaskGroup(of: (String, Round?).self) { group in
            for roundId in roundIds {
                group.addTask {
                    let round = try? await self.roundsRepository.fetchRound(id: roundId)
                    return (roundId, round)
                }
            }

            for await (roundId, round) in group {
                if let round = round {
                    linkedRounds[roundId] = round
                }
            }
        }
    }

    // MARK: - Load Feed

    func loadFeed() async {
        // Skip if already has data and currently loading
        let hasData = !posts.isEmpty
        guard !hasData || !isLoading else { return }

        if useAdvancedRanking {
            await loadFeedAdvanced()
        } else {
            await loadFeedLegacy()
        }
    }

    private func loadFeedLegacy() async {
        isLoading = true
        errorMessage = nil

        print("📝 [Feed] Loading feed (legacy) with filter: \(filter)")

        do {
            let fetchedPosts = try await postsRepository.fetchFeed(
                filter: filter,
                limit: FeedConstants.defaultPageSize,
                after: nil
            )

            print("📝 [Feed] Loaded \(fetchedPosts.count) posts")
            posts = fetchedPosts
            lastPostDate = fetchedPosts.last?.createdAt
            hasMorePosts = fetchedPosts.count >= FeedConstants.defaultPageSize

            // Load linked rounds
            await loadLinkedRounds(for: fetchedPosts)
        } catch {
            print("📝 [Feed] Error loading feed: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadFeedAdvanced() async {
        guard let uid = currentUid() else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        print("📝 [Feed] Loading feed (advanced) with filter: \(filter)")

        do {
            // Reset cursors and seen posts on initial load
            friendsFeedCursor = nil
            publicFeedCursor = nil
            seenPostIds.removeAll()

            // Initialize viewer context if needed
            if viewerContext == nil {
                let profile = try? await profileRepository.fetchPublicProfile(uid: uid)
                viewerContext = ViewerContext.from(userId: uid, profile: profile)
            }

            let fetchedPosts: [Post]
            switch filter {
            case .friendsOnly:
                fetchedPosts = try await loadFriendsFeedRanked(uid: uid, isInitial: true)
            case .all:
                fetchedPosts = try await loadPublicFeedRanked(uid: uid, isInitial: true)
            }

            print("📝 [Feed] Loaded \(fetchedPosts.count) ranked posts")
            posts = fetchedPosts
            hasMorePosts = fetchedPosts.count >= config.feedPageSize

            // Load linked rounds
            await loadLinkedRounds(for: fetchedPosts)
        } catch {
            print("📝 [Feed] Error loading advanced feed: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        if useAdvancedRanking {
            await refreshAdvanced()
        } else {
            await refreshLegacy()
        }

        isRefreshing = false
    }

    private func refreshLegacy() async {
        do {
            let fetchedPosts = try await postsRepository.fetchFeed(
                filter: filter,
                limit: FeedConstants.defaultPageSize,
                after: nil
            )

            posts = fetchedPosts
            lastPostDate = fetchedPosts.last?.createdAt
            hasMorePosts = fetchedPosts.count >= FeedConstants.defaultPageSize
            errorMessage = nil

            // Load linked rounds
            await loadLinkedRounds(for: fetchedPosts)
        } catch {
            // Don't overwrite existing posts on refresh failure
            print("Refresh failed: \(error)")
        }
    }

    private func refreshAdvanced() async {
        guard let uid = currentUid() else { return }

        do {
            // Reset cursors and seen posts
            friendsFeedCursor = nil
            publicFeedCursor = nil
            seenPostIds.removeAll()

            let fetchedPosts: [Post]
            switch filter {
            case .friendsOnly:
                fetchedPosts = try await loadFriendsFeedRanked(uid: uid, isInitial: true)
            case .all:
                fetchedPosts = try await loadPublicFeedRanked(uid: uid, isInitial: true)
            }

            posts = fetchedPosts
            hasMorePosts = fetchedPosts.count >= config.feedPageSize
            errorMessage = nil

            // Load linked rounds
            await loadLinkedRounds(for: fetchedPosts)
        } catch {
            print("Refresh failed: \(error)")
        }
    }
    
    // MARK: - Load More (Pagination)
    
    func loadMore() async {
        guard !isLoadingMore, hasMorePosts, let cursor = lastPostDate else { return }
        
        isLoadingMore = true
        
        do {
            let morePosts = try await postsRepository.fetchFeed(
                filter: filter,
                limit: FeedConstants.defaultPageSize,
                after: cursor
            )
            
            posts.append(contentsOf: morePosts)
            lastPostDate = morePosts.last?.createdAt ?? lastPostDate
            hasMorePosts = morePosts.count >= FeedConstants.defaultPageSize
        } catch {
            print("Load more failed: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Filter Change
    
    func setFilter(_ newFilter: FeedFilter) async {
        guard newFilter != filter else { return }
        filter = newFilter
        posts = []
        lastPostDate = nil
        hasMorePosts = true
        await loadFeed()
    }
    
    // MARK: - Upvote

    func toggleUpvote(for post: Post) async {
        guard let postId = post.id else { return }

        // Optimistic update
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let currentlyUpvoted = posts[index].hasUpvoted ?? false
            posts[index].hasUpvoted = !currentlyUpvoted
            // Never let count go below 0 on client side
            let delta = currentlyUpvoted ? -1 : 1
            posts[index].upvoteCount = max(0, posts[index].upvoteCount + delta)
        }

        do {
            // Returns true if upvoted, false if removed
            // Count will be updated asynchronously by Cloud Function
            _ = try await postsRepository.toggleUpvote(postId: postId)
        } catch {
            // Revert optimistic update on error
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let currentlyUpvoted = posts[index].hasUpvoted ?? false
                posts[index].hasUpvoted = !currentlyUpvoted
                // Never let count go below 0 on revert either
                let delta = currentlyUpvoted ? -1 : 1
                posts[index].upvoteCount = max(0, posts[index].upvoteCount + delta)
            }
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Post Created (called from CreatePostView)
    
    func postCreated(_ post: Post) {
        // Insert new post at the beginning
        posts.insert(post, at: 0)
    }
    
    // MARK: - Post Updated
    
    func postUpdated(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
    
    // MARK: - Post Deleted
    
    func postDeleted(_ postId: String) {
        posts.removeAll { $0.id == postId }
    }

    // MARK: - Advanced Ranking (Phase 4.2)

    private func loadFriendsFeedRanked(uid: String, isInitial: Bool) async throws -> [Post] {
        // Fetch following list
        var followingUids = try await socialRepository.getFollowing()

        // Include own posts in friends feed
        followingUids.append(uid)

        print("📝 [Feed] Friends feed for \(uid), following: \(followingUids.count) users")

        guard !followingUids.isEmpty else { return [] }

        // Try multiple time windows if not enough posts
        var candidates: [Post] = []
        let windows = [config.primaryWindowDays, config.fallbackWindow1Days, config.fallbackWindow2Days]

        for windowDays in windows {
            let windowStart = Date().addingTimeInterval(-Double(windowDays) * 24 * 60 * 60)

            candidates = try await postsRepository.fetchFriendsPostsCandidates(
                authorUids: Array(followingUids.prefix(30)),
                windowStart: windowStart,
                limit: config.bucketFetchLimit
            )

            // If we have enough posts, stop expanding window
            if candidates.count >= config.feedPageSize {
                break
            }
        }

        // Only deduplicate if paginating (not initial load)
        if !isInitial {
            candidates = rankingService.deduplicate(candidates, seen: seenPostIds)
        }

        // Fetch stats for candidates
        let postIds = candidates.compactMap { $0.id }
        let postStatsMap = try await postsRepository.fetchPostStatsBatch(postIds: postIds)
        let authorUids = Array(Set(candidates.map { $0.authorUid }))
        let userStatsMap = try await postsRepository.fetchUserStatsBatch(uids: authorUids)

        print("📝 [Feed] Stats fetched - Posts: \(postStatsMap.count)/\(postIds.count), Users: \(userStatsMap.count)/\(authorUids.count)")

        // Score posts (create fallback stats for old posts without stats)
        var scoredPosts = candidates.compactMap { post -> ScoredPost? in
            guard let postId = post.id, let context = viewerContext else { return nil }

            // Create fallback stats if missing (for old posts created before Cloud Functions)
            let stats = postStatsMap[postId] ?? PostStats(
                postId: postId,
                upvoteCount: post.upvoteCount,
                commentCount: post.commentCount,
                lastEngagementAt: post.createdAt,
                hotScore7d: 0,
                updatedAt: post.createdAt
            )

            let authorStats = userStatsMap[post.authorUid] ?? UserStats(
                userId: post.authorUid,
                accountCreatedAt: post.createdAt.addingTimeInterval(-30 * 24 * 60 * 60), // Assume old account
                postCount: 10, // Assume not new author
                isNewAuthor: false,
                updatedAt: post.createdAt
            )

            let score = rankingService.computeScore(
                viewerContext: context,
                post: post,
                postStats: stats,
                authorStats: authorStats,
                isFriendsFeed: true
            )

            return ScoredPost(post: post, score: score)
        }

        print("📝 [Feed] Friends Feed scored \(scoredPosts.count) posts from \(candidates.count) candidates")

        // Sort by score
        scoredPosts = rankingService.sortByScore(scoredPosts)

        // Enforce diversity
        scoredPosts = rankingService.enforceDiversity(scoredPosts)

        // Take page
        let page = Array(scoredPosts.prefix(config.feedPageSize))
        var result = page.map { $0.post }

        // Hydrate upvote status
        for i in result.indices {
            result[i].hasUpvoted = try? await postsRepository.hasUpvoted(postId: result[i].id ?? "")
        }

        // Update cursor and seen (for pagination)
        if let last = result.last {
            friendsFeedCursor = FriendsFeedCursor(
                lastCreatedAt: last.createdAt,
                lastPostId: last.id ?? ""
            )
        }

        // Track seen IDs only for pagination (to prevent duplicates when loading more)
        if !isInitial {
            result.forEach { if let id = $0.id { seenPostIds.insert(id) } }
        }

        return result
    }

    private func loadPublicFeedRanked(uid: String, isInitial: Bool) async throws -> [Post] {
        // For public feed, use 30-day window to ensure discovery
        let windowStart = Date().addingTimeInterval(-Double(config.fallbackWindow1Days) * 24 * 60 * 60)

        // Fetch 3 buckets concurrently
        async let recentPosts = try postsRepository.fetchRecentPublicPosts(
            windowStart: windowStart,
            limit: config.bucketFetchLimit
        )

        async let trendingIds = try postsRepository.fetchTrendingPostIds(
            limit: Int(Double(config.bucketFetchLimit) * config.trendingBucketWeight)
        )

        async let newCreatorsPosts = try postsRepository.fetchNewCreatorsPosts(
            windowStart: windowStart,
            limit: Int(Double(config.bucketFetchLimit) * config.newCreatorsBucketWeight)
        )

        let (recent, trendingTuples, newCreators) = try await (recentPosts, trendingIds, newCreatorsPosts)

        // Fetch trending posts by IDs
        let trendingPostIds = trendingTuples.map { $0.0 }
        let trending = try await postsRepository.fetchPostsByIds(trendingPostIds)

        // Only deduplicate if paginating (not initial load)
        let recentDedupe: [Post]
        let trendingDedupe: [Post]
        let newCreatorsDedupe: [Post]

        if isInitial {
            recentDedupe = recent
            trendingDedupe = trending
            newCreatorsDedupe = newCreators
        } else {
            recentDedupe = rankingService.deduplicate(recent, seen: seenPostIds)
            trendingDedupe = rankingService.deduplicate(trending, seen: seenPostIds)
            newCreatorsDedupe = rankingService.deduplicate(newCreators, seen: seenPostIds)
        }

        // Fetch stats for all candidates
        let allCandidates = recentDedupe + trendingDedupe + newCreatorsDedupe
        let postIds = allCandidates.compactMap { $0.id }
        let postStatsMap = try await postsRepository.fetchPostStatsBatch(postIds: postIds)
        let authorUids = Array(Set(allCandidates.map { $0.authorUid }))
        let userStatsMap = try await postsRepository.fetchUserStatsBatch(uids: authorUids)

        print("📝 [Feed] Public Feed Stats - Posts: \(postStatsMap.count)/\(postIds.count), Users: \(userStatsMap.count)/\(authorUids.count)")

        // Score all buckets (create fallback stats for old posts)
        func scorePostsBucket(_ posts: [Post]) -> [ScoredPost] {
            return posts.compactMap { post in
                guard let postId = post.id, let context = viewerContext else { return nil }

                // Create fallback stats if missing
                let stats = postStatsMap[postId] ?? PostStats(
                    postId: postId,
                    upvoteCount: post.upvoteCount,
                    commentCount: post.commentCount,
                    lastEngagementAt: post.createdAt,
                    hotScore7d: 0,
                    updatedAt: post.createdAt
                )

                let authorStats = userStatsMap[post.authorUid] ?? UserStats(
                    userId: post.authorUid,
                    accountCreatedAt: post.createdAt.addingTimeInterval(-30 * 24 * 60 * 60),
                    postCount: 10,
                    isNewAuthor: false,
                    updatedAt: post.createdAt
                )

                let score = rankingService.computeScore(
                    viewerContext: context,
                    post: post,
                    postStats: stats,
                    authorStats: authorStats,
                    isFriendsFeed: false
                )

                return ScoredPost(post: post, score: score)
            }
        }

        let recentScored = rankingService.sortByScore(scorePostsBucket(recentDedupe))
        let trendingScored = rankingService.sortByScore(scorePostsBucket(trendingDedupe))
        let newCreatorsScored = rankingService.sortByScore(scorePostsBucket(newCreatorsDedupe))

        print("📝 [Feed] Bucket sizes - Recent: \(recentScored.count), Trending: \(trendingScored.count), NewCreators: \(newCreatorsScored.count)")

        // Deduplicate across buckets (prioritize Recent > Trending > New Creators)
        let recentPostIds = Set(recentScored.compactMap { $0.post.id })
        let trendingDeduped = trendingScored.filter { !recentPostIds.contains($0.post.id ?? "") }

        let combinedPostIds = recentPostIds.union(Set(trendingDeduped.compactMap { $0.post.id }))
        let newCreatorsDeduped = newCreatorsScored.filter { !combinedPostIds.contains($0.post.id ?? "") }

        print("📝 [Feed] After dedup - Recent: \(recentScored.count), Trending: \(trendingDeduped.count), NewCreators: \(newCreatorsDeduped.count)")

        // Generate seed for deterministic mixing
        let dateKey = PublicFeedCursor.todayKey()
        let seed = rankingService.generateSeed(viewerId: uid, dateKey: dateKey)

        // Interleave buckets (using deduplicated buckets)
        var mixed = rankingService.interleaveBuckets(
            recent: recentScored,
            trending: trendingDeduped,
            newCreators: newCreatorsDeduped,
            seed: seed,
            count: config.feedPageSize * 3  // Fetch more for diversity enforcement
        )

        // Enforce diversity
        mixed = rankingService.enforceDiversity(mixed)

        // Take page
        let page = Array(mixed.prefix(config.feedPageSize))
        var result = page.map { $0.post }

        // Hydrate upvote status
        for i in result.indices {
            result[i].hasUpvoted = try? await postsRepository.hasUpvoted(postId: result[i].id ?? "")
        }

        // Update cursor and seen (for pagination)
        let cursor = publicFeedCursor ?? PublicFeedCursor()
        publicFeedCursor = PublicFeedCursor(
            dateKey: cursor.dateKey,
            recentOffset: cursor.recentOffset + recentScored.count,
            trendingOffset: cursor.trendingOffset + trendingDeduped.count,
            newCreatorsOffset: cursor.newCreatorsOffset + newCreatorsDeduped.count,
            seenPostIds: Array(seenPostIds.prefix(100))
        )

        // Track seen IDs only for pagination (to prevent duplicates when loading more)
        if !isInitial {
            result.forEach { if let id = $0.id { seenPostIds.insert(id) } }
        }

        return result
    }
}


