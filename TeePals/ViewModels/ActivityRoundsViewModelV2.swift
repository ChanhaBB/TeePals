import Foundation
import UIKit

/// Unified Activity view model - consolidates Hosting, Participating, and Invited into one feed.
@MainActor
final class ActivityRoundsViewModelV2: ObservableObject {

    // MARK: - Dependencies

    private let activityService: ActivityRoundsService
    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var selectedFilter: ActivityFilter = .all
    @Published var expandedSections: Set<ActivitySection> = [.actionRequired, .upcoming]

    @Published private(set) var allRounds: [ActivityRoundItem] = []
    @Published private(set) var currentUserProfile: PublicProfile?

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoadedOnce = false

    // MARK: - Init

    init(
        activityService: ActivityRoundsService,
        roundsRepository: RoundsRepository,
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.activityService = activityService
        self.roundsRepository = roundsRepository
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }

    // MARK: - Computed Properties

    /// Rounds grouped by section and filtered.
    var groupedRounds: [ActivitySection: [ActivityRoundItem]] {
        let filtered = filteredRounds
        var groups: [ActivitySection: [ActivityRoundItem]] = [:]

        // Action Required
        groups[.actionRequired] = filtered
            .filter { item in
                // Invited rounds need action
                if item.needsAction {
                    return true
                }
                // Hosting rounds with pending requests need action
                if item.role == .hosting && item.round.requestCount > 0 && item.isFuture {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                // Sort by round date asc, then newest request/invite desc
                if let lhsDate = lhs.round.startTime, let rhsDate = rhs.round.startTime {
                    if lhsDate != rhsDate {
                        return lhsDate < rhsDate
                    }
                }
                // Same round date or no date - sort by invite/request date desc
                if let lhsInvited = lhs.invitedAt, let rhsInvited = rhs.invitedAt {
                    return lhsInvited > rhsInvited
                }
                return false
            }

        // Upcoming (non-requested)
        let upcomingNonRequested = filtered
            .filter { $0.isFuture && !$0.needsAction && $0.status != .requested }
            .sorted { lhs, rhs in
                // Sort by badge priority (hosting > confirmed), then by date asc
                if lhs.badge != rhs.badge {
                    return lhs.badge == .hosting
                }
                if let lhsDate = lhs.round.startTime, let rhsDate = rhs.round.startTime {
                    return lhsDate < rhsDate
                }
                return false
            }
        groups[.upcoming] = upcomingNonRequested

        // Pending Approval (requested status)
        let pendingApproval = filtered
            .filter { $0.status == .requested && $0.isFuture }
            .sorted { lhs, rhs in
                // Sort by round date asc
                if let lhsDate = lhs.round.startTime, let rhsDate = rhs.round.startTime {
                    return lhsDate < rhsDate
                }
                return false
            }
        groups[.pendingApproval] = pendingApproval

        // Past
        let past = filtered
            .filter { !$0.isFuture }
            .sorted { lhs, rhs in
                // Sort by badge priority (hosting > played), then by date desc
                if lhs.badge != rhs.badge {
                    return lhs.badge == .hosting
                }
                if let lhsDate = lhs.round.startTime, let rhsDate = rhs.round.startTime {
                    return lhsDate > rhsDate  // Descending for past
                }
                return false
            }
        groups[.past] = past

        return groups
    }

    /// Filtered rounds based on selected filter.
    private var filteredRounds: [ActivityRoundItem] {
        switch selectedFilter {
        case .all:
            return allRounds
        case .hosting:
            return allRounds.filter { $0.role == .hosting }
        case .playing:
            return allRounds.filter { $0.role == .participating }
        }
    }

    var isEmpty: Bool {
        allRounds.isEmpty && !isLoading && hasLoadedOnce
    }

    // MARK: - Load Data

    func loadActivity(dateRange: DateRangeOption = .next30) async {
        guard !hasLoadedOnce else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        // Load all data concurrently
        async let hostingRounds = loadHostingRounds(dateRange: dateRange)
        async let requestedRounds = loadRequestedRounds(dateRange: dateRange)
        async let invitedRounds = loadInvitedRounds()

        let (hosting, requested, invited) = await (hostingRounds, requestedRounds, invitedRounds)

        // Combine all rounds
        var items: [ActivityRoundItem] = []
        items.append(contentsOf: hosting)
        items.append(contentsOf: requested)
        items.append(contentsOf: invited)

        allRounds = items
    }

    func refresh(dateRange: DateRangeOption = .next30) async {
        guard !isLoading else { return }

        hasLoadedOnce = false
        await loadActivity(dateRange: dateRange)
    }

    // MARK: - Private Loading

    private func loadHostingRounds(dateRange: DateRangeOption) async -> [ActivityRoundItem] {
        do {
            var rounds = try await activityService.fetchHostingRounds(dateRange: dateRange)

            // Load current user profile if not loaded
            if currentUserProfile == nil, let uid = currentUid() {
                currentUserProfile = try? await profileRepository.fetchPublicProfile(uid: uid)
            }

            // Fetch actual pending request counts from members subcollection
            for index in rounds.indices {
                guard let roundId = rounds[index].id else { continue }

                // Fetch all members with .requested status
                let members = try? await roundsRepository.fetchMembers(roundId: roundId)
                let pendingCount = members?.filter { $0.status == .requested }.count ?? 0

                // Update the round's requestCount with actual value
                rounds[index].requestCount = pendingCount
            }

            return rounds.map { round in
                ActivityRoundItem(
                    round: round,
                    role: .hosting,
                    status: nil,
                    requestedAt: nil,
                    invitedAt: nil,
                    hostProfile: currentUserProfile,
                    inviterName: nil
                )
            }
        } catch {
            print("Failed to load hosting rounds: \(error)")
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
            return []
        }
    }

    private func loadRequestedRounds(dateRange: DateRangeOption) async -> [ActivityRoundItem] {
        do {
            let requests = try await activityService.fetchRequestedRounds(dateRange: dateRange)

            // Load host profiles
            let hostUids = Set(requests.map { $0.round.hostUid })
            let hostProfiles = await loadProfiles(for: hostUids)

            // Preload profile images
            await preloadProfileImages(for: Array(hostProfiles.values))

            return requests.map { request in
                ActivityRoundItem(
                    round: request.round,
                    role: .participating,
                    status: request.status,
                    requestedAt: request.requestedAt,
                    invitedAt: nil,
                    hostProfile: hostProfiles[request.round.hostUid],
                    inviterName: nil
                )
            }
        } catch {
            print("Failed to load requested rounds: \(error)")
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
            return []
        }
    }

    private func loadInvitedRounds() async -> [ActivityRoundItem] {
        do {
            let rounds = try await roundsRepository.fetchInvitedRounds()

            // Fetch member records and host profiles
            var items: [ActivityRoundItem] = []

            for round in rounds {
                guard let roundId = round.id else { continue }

                // Fetch membership status to get invite date and inviter
                let member = try? await roundsRepository.fetchMembershipStatus(roundId: roundId)

                // Fetch host profile
                let hostProfile = try? await profileRepository.fetchPublicProfile(uid: round.hostUid)

                // Fetch inviter name if available
                var inviterName: String?
                if let invitedBy = member?.invitedBy {
                    let inviterProfile = try? await profileRepository.fetchPublicProfile(uid: invitedBy)
                    inviterName = inviterProfile?.nickname
                }

                items.append(ActivityRoundItem(
                    round: round,
                    role: .participating,
                    status: .invited,
                    requestedAt: nil,
                    invitedAt: member?.createdAt,
                    hostProfile: hostProfile,
                    inviterName: inviterName
                ))
            }

            // Preload profile images
            let profiles = items.compactMap { $0.hostProfile }
            await preloadProfileImages(for: profiles)

            return items
        } catch {
            print("Failed to load invited rounds: \(error)")
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
            return []
        }
    }

    // MARK: - Invited Actions

    func acceptInvite(roundId: String) async {
        do {
            try await roundsRepository.acceptInvite(roundId: roundId)

            // Remove from list
            allRounds.removeAll { $0.round.id == roundId && $0.status == .invited }
        } catch {
            print("Failed to accept invite: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(roundId: String) async {
        do {
            try await roundsRepository.declineInvite(roundId: roundId)

            // Remove from list
            allRounds.removeAll { $0.round.id == roundId && $0.status == .invited }
        } catch {
            print("Failed to decline invite: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Section Management

    func toggleSection(_ section: ActivitySection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    func isSectionExpanded(_ section: ActivitySection) -> Bool {
        expandedSections.contains(section)
    }

    // MARK: - Helpers

    private func loadProfiles(for uids: Set<String>) async -> [String: PublicProfile] {
        await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in uids {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var profiles: [String: PublicProfile] = [:]
            for await (uid, profile) in group {
                if let profile = profile {
                    profiles[uid] = profile
                }
            }
            return profiles
        }
    }

    private func preloadProfileImages(for profiles: [PublicProfile]) async {
        let photoURLs = profiles.compactMap { profile -> URL? in
            guard let urlString = profile.photoUrls.first else { return nil }
            return URL(string: urlString)
        }

        guard !photoURLs.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for url in photoURLs {
                group.addTask {
                    if ImageCache.shared.get(for: url) != nil { return }

                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            ImageCache.shared.set(image, for: url)
                        }
                    } catch {
                        // Silently fail
                    }
                }
            }
        }
    }
}
