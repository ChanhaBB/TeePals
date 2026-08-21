import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Dependencies

    private let profileRepository: ProfileRepository
    private let socialRepository: SocialRepository
    private let activityService: ActivityRoundsService
    private let roundsRepository: RoundsRepository
    private let currentUid: () -> String?

    // MARK: - Target User

    /// The UID of the profile to display. If nil, shows the current user's own profile.
    private let targetUid: String?

    // MARK: - Published State

    @Published var isLoading = true // Start true to show skeleton on first load
    @Published var errorMessage: String?

    @Published var publicProfile: PublicProfile?
    @Published var privateProfile: PrivateProfile?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0

    // Follow state (only relevant for other user profiles)
    @Published var isFollowing = false
    @Published var isMutualFollow = false
    @Published var isFollowedByThem = false

    // Past rounds state
    @Published var pastRounds: [ActivityRoundItem] = []
    @Published var isPastRoundsLoading = false
    @Published var hasAttemptedPastRoundsLoad = false

    // MARK: - Computed

    var hasProfile: Bool {
        publicProfile != nil
    }

    /// Returns the UID of the profile being viewed
    var uid: String? {
        targetUid ?? currentUid()
    }

    /// Whether this is the current user's own profile
    var isOwnProfile: Bool {
        targetUid == nil || targetUid == currentUid()
    }

    /// Display name for navigation title
    var displayName: String {
        publicProfile?.fullName ?? "Profile"
    }

    /// Accurate age from private profile, falls back to public profile approximation
    var age: Int? {
        privateProfile?.age ?? publicProfile?.age
    }

    // MARK: - Init

    init(
        uid: String? = nil,
        profileRepository: ProfileRepository,
        socialRepository: SocialRepository,
        activityService: ActivityRoundsService,
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.targetUid = uid
        self.profileRepository = profileRepository
        self.socialRepository = socialRepository
        self.activityService = activityService
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Load Profile

    func loadProfile() async {
        guard let profileUid = uid else {
            errorMessage = "Not signed in"
            isLoading = false
            return
        }

        // On subsequent loads with cache, hide loading immediately
        let hasCache = publicProfile != nil
        if hasCache {
            isLoading = false
        }
        errorMessage = nil

        // Load profile and social data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchPublicProfile(uid: profileUid)
            }

            // Only load private profile for own profile
            if self.isOwnProfile {
                group.addTask {
                    await self.fetchPrivateProfile(uid: profileUid)
                }
            }

            group.addTask {
                await self.fetchSocialCounts(uid: profileUid)
            }

            // Load follow state for other user profiles
            if !self.isOwnProfile {
                group.addTask {
                    await self.fetchFollowState(uid: profileUid)
                }
            }
        }

        // Always stop loading after data arrives
        isLoading = false
    }
    
    private func fetchPublicProfile(uid: String) async {
        do {
            publicProfile = try await profileRepository.fetchPublicProfile(uid: uid)
        } catch {
            // Don't show error for missing profile - user may need to set up
            if let repoError = error as? ProfileRepositoryError, repoError == .notFound {
                return
            }
            errorMessage = "Failed to load profile"
        }
    }

    private func fetchPrivateProfile(uid: String) async {
        do {
            privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid)
        } catch {
            // Private profile is optional, don't show error
            print("Failed to fetch private profile: \(error)")
        }
    }

    private func fetchSocialCounts(uid: String) async {
        do {
            async let followerCountData = socialRepository.getFollowerCount(uid: uid)
            async let followingCountData = socialRepository.getFollowingCount(uid: uid)

            let (followers, following) = try await (followerCountData, followingCountData)
            followerCount = followers
            followingCount = following
        } catch {
            // Social counts failing is non-critical, just log
            print("Failed to fetch social counts: \(error)")
        }
    }

    private func fetchFollowState(uid: String) async {
        do {
            async let following = socialRepository.isFollowing(targetUid: uid)
            async let mutual = socialRepository.isMutualFollow(targetUid: uid)
            async let followedBy = socialRepository.isFollowedBy(targetUid: uid)

            let (isFollowingResult, isMutualResult, isFollowedByResult) = try await (following, mutual, followedBy)
            isFollowing = isFollowingResult
            isMutualFollow = isMutualResult
            isFollowedByThem = isFollowedByResult
        } catch {
            print("Failed to fetch follow state: \(error)")
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadProfile()
    }

    /// Force a full refresh by clearing cache first
    func forceRefresh() async {
        // Clear cached profile to force fresh fetch
        publicProfile = nil
        isLoading = true
        await loadProfile()
    }

    // MARK: - Past Rounds

    /// Load past rounds for the profile being viewed.
    /// For own profile: loads hosting + participated (accepted) rounds via activityService.
    /// For other user: loads only rounds they hosted (participating rounds aren't queryable without a collection group index).
    func loadPastRounds() async {
        guard uid != nil else { return }

        isPastRoundsLoading = true

        do {
            let items: [ActivityRoundItem]
            if isOwnProfile {
                items = try await loadOwnPastRounds()
            } else {
                items = try await loadOtherUserPastRounds()
            }

            pastRounds = Array(
                items
                    .filter { item in
                        guard let startTime = item.round.startTime else { return false }
                        return startTime < Date()
                    }
                    .sorted { lhs, rhs in
                        guard let l = lhs.round.startTime, let r = rhs.round.startTime else { return false }
                        return l > r
                    }
                    .prefix(20)
            )

            isPastRoundsLoading = false
            hasAttemptedPastRoundsLoad = true
        } catch {
            print("Failed to load past rounds: \(error)")
            isPastRoundsLoading = false
            hasAttemptedPastRoundsLoad = true
        }
    }

    private func loadOwnPastRounds() async throws -> [ActivityRoundItem] {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let pastDateRange = DateRangeOption.custom(start: oneYearAgo, end: yesterday)

        async let hostingRounds = activityService.fetchHostingRounds(dateRange: pastDateRange, includeCompleted: true)
        async let requestedRounds = activityService.fetchRequestedRounds(dateRange: pastDateRange)
        let (hosting, requests) = try await (hostingRounds, requestedRounds)

        var items: [ActivityRoundItem] = hosting.map { round in
            ActivityRoundItem(
                round: round,
                role: .hosting,
                status: nil,
                requestedAt: nil,
                invitedAt: nil,
                hostProfile: publicProfile,
                inviterName: nil,
                inviterPhotoURL: nil
            )
        }

        // Accepted / completed participating rounds — resolve host profiles concurrently
        let participatingRounds = requests.filter { $0.status == .accepted }
        let participatingItems: [ActivityRoundItem] = await withTaskGroup(of: ActivityRoundItem.self) { group in
            for request in participatingRounds {
                group.addTask {
                    let hostProfile = request.round.hostUid.isEmpty ? nil :
                        (try? await self.profileRepository.fetchPublicProfile(uid: request.round.hostUid))
                    return ActivityRoundItem(
                        round: request.round,
                        role: .participating,
                        status: request.status,
                        requestedAt: request.requestedAt,
                        invitedAt: nil,
                        hostProfile: hostProfile,
                        inviterName: nil,
                        inviterPhotoURL: nil
                    )
                }
            }
            var results: [ActivityRoundItem] = []
            for await item in group { results.append(item) }
            return results
        }
        items.append(contentsOf: participatingItems)
        return items
    }

    private func loadOtherUserPastRounds() async throws -> [ActivityRoundItem] {
        guard let targetUid else { return [] }

        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let pastRange = DateRangeOption.custom(start: oneYearAgo, end: Date())

        // ── Step 1: Fetch round data in parallel ──────────────────────────────────
        // These two queries tell us what the target has played. No visibility filter
        // yet — we apply it in memory after resolving who the hosts are.
        async let hostedTask       = roundsRepository.fetchRounds(
            filters: RoundFilters(
                status: nil,
                skipVisibilityFilter: true,
                dateRange: pastRange,
                excludeFullRounds: false,
                hostUid: targetUid
            ),
            limit: 30,
            lastRound: nil
        )
        async let participatedTask = activityService.fetchParticipatedRounds(for: targetUid, dateRange: pastRange)

        let (hostedRounds, participatedRequests) = try await (hostedTask, participatedTask)

        let now = Date()
        let allRounds: [(round: Round, role: ActivityRole, request: RoundRequest?)] =
            hostedRounds
                .filter { ($0.startTime ?? now) < now }
                .map { ($0, .hosting, nil) }
            + participatedRequests
                .filter { ($0.round.startTime ?? now) < now }
                .map { ($0.round, .participating, $0) }

        guard !allRounds.isEmpty else { return [] }

        // ── Step 2: Collect only the host UIDs we actually need to check ───────────
        // Visibility is a viewer ↔ host relationship. We only need social graph checks
        // for non-public rounds, and only for the specific hosts that appear in the
        // fetched rounds. This is O(unique hosts) not O(viewer's total friend count).
        let nonPublicHostUids = Set(
            allRounds
                .filter { $0.round.visibility != .public }
                .map { $0.round.hostUid }
        )

        // ── Step 3: Resolve viewer's access for non-public hosts in parallel ──────
        // For each unique non-public host: check mutual follow (friends check).
        // For private rounds: also need viewer's member round IDs.
        // Both resolve concurrently.
        // ── Step 3: Resolve viewer's access for non-public hosts in parallel ──────
        // Both tasks start immediately and run concurrently:
        //   a) Mutual follow check per unique non-public host
        //      isMutualFollow = 2 reads per host; ~10-20 unique hosts → ~20-40 reads total.
        //      Completely independent of how large the viewer's total friend count is.
        //   b) Viewer's accepted member round IDs (one collectionGroup query)
        //      Needed only for .private round visibility checks.

        async let memberRoundIdsTask = activityService.fetchViewerMemberRoundIds()

        var friendHostUids = Set<String>()
        await withTaskGroup(of: (String, Bool).self) { group in
            for hostUid in nonPublicHostUids {
                group.addTask {
                    let isMutual = (try? await self.socialRepository.isMutualFollow(targetUid: hostUid)) ?? false
                    return (hostUid, isMutual)
                }
            }
            for await (uid, isMutual) in group {
                if isMutual { friendHostUids.insert(uid) }
            }
        }

        let viewerMemberRoundIds = (try? await memberRoundIdsTask) ?? []

        // ── Step 4: Pure O(1) visibility check per round ──────────────────────────
        func viewerCanSee(_ round: Round) -> Bool {
            switch round.visibility {
            case .public:  return true
            case .friends: return friendHostUids.contains(round.hostUid)
            case .private: return viewerMemberRoundIds.contains(round.id ?? "")
            }
        }

        // ── Step 5: Build final items, deduplicating by round ID ─────────────────
        var seenIds = Set<String>()
        var visibleEntries: [(round: Round, role: ActivityRole, request: RoundRequest?)] = []

        for entry in allRounds {
            guard let id = entry.round.id,
                  !seenIds.contains(id),
                  viewerCanSee(entry.round) else { continue }
            seenIds.insert(id)
            visibleEntries.append(entry)
        }

        // ── Step 6: Resolve host profiles concurrently ───────────────────────────
        // Hosted rounds already have the host profile from publicProfile (already loaded).
        // Participated rounds need the third-party host's profile fetched.
        // Collect unique host UIDs for participated rounds and fetch in parallel.
        let participatedHostUids = Set(
            visibleEntries
                .filter { $0.role == .participating }
                .map { $0.round.hostUid }
        )

        var hostProfileCache: [String: PublicProfile] = [:]
        if !participatedHostUids.isEmpty {
            hostProfileCache = await withTaskGroup(of: (String, PublicProfile?).self) { group in
                for hostUid in participatedHostUids {
                    group.addTask {
                        let profile = try? await self.profileRepository.fetchPublicProfile(uid: hostUid)
                        return (hostUid, profile)
                    }
                }
                var cache: [String: PublicProfile] = [:]
                for await (uid, profile) in group {
                    if let profile { cache[uid] = profile }
                }
                return cache
            }
        }

        return visibleEntries.map { entry in
            let hostProfile: PublicProfile? = entry.role == .hosting
                ? publicProfile
                : hostProfileCache[entry.round.hostUid]
            return ActivityRoundItem(
                round: entry.round,
                role: entry.role,
                status: entry.request?.status,
                requestedAt: entry.request?.requestedAt,
                invitedAt: nil,
                hostProfile: hostProfile,
                inviterName: nil,
                inviterPhotoURL: nil
            )
        }
    }

    // MARK: - Follow Actions

    /// Toggle follow state for the target user
    func toggleFollow() async {
        guard let targetUid = targetUid, !isOwnProfile else { return }

        do {
            if isFollowing {
                // Unfollow
                try await socialRepository.unfollow(targetUid: targetUid)
                isFollowing = false
                isMutualFollow = false
                followerCount = max(0, followerCount - 1)
            } else {
                // Follow
                try await socialRepository.follow(targetUid: targetUid)
                isFollowing = true
                followerCount += 1

                // Check if it became mutual
                if isFollowedByThem {
                    isMutualFollow = true
                }
            }
        } catch {
            errorMessage = "Failed to update follow status"
            print("Toggle follow error: \(error)")
        }
    }
}

