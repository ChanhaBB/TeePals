import Foundation
import Nuke

/// ViewModel for the Activity tab — supports Schedule, Invites, and Past chips.
@MainActor
final class ActivityRoundsViewModelV2: ObservableObject {

    // MARK: - Dependencies

    private let activityService: ActivityRoundsService
    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var selectedTab: ActivityTab = .schedule

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

    /// Confirmed + hosting rounds only (no pending requests). Soonest first.
    var scheduleRounds: [ActivityRoundItem] {
        allRounds
            .filter { $0.isFuture && !$0.needsAction && !$0.isPending }
            .sorted { lhs, rhs in
                guard let l = lhs.round.startTime, let r = rhs.round.startTime else { return false }
                return l < r
            }
    }

    /// Invited rounds awaiting user action.
    var inviteRounds: [ActivityRoundItem] {
        allRounds
            .filter { $0.needsAction }
            .sorted { lhs, rhs in
                guard let l = lhs.round.startTime, let r = rhs.round.startTime else { return false }
                return l < r
            }
    }

    /// Outbound requests waiting on the host.
    var pendingRounds: [ActivityRoundItem] {
        allRounds
            .filter { $0.isPending && $0.isFuture }
            .sorted { lhs, rhs in
                guard let l = lhs.round.startTime, let r = rhs.round.startTime else { return false }
                return l < r
            }
    }

    /// Past rounds, most recent first.
    var pastRounds: [ActivityRoundItem] {
        allRounds
            .filter { !$0.isFuture && !$0.needsAction }
            .sorted { lhs, rhs in
                guard let l = lhs.round.startTime, let r = rhs.round.startTime else { return false }
                return l > r
            }
    }

    var inviteCount: Int { inviteRounds.count }
    var pendingCount: Int { pendingRounds.count }

    var isCurrentTabEmpty: Bool {
        switch selectedTab {
        case .schedule: return scheduleRounds.isEmpty
        case .invites: return inviteRounds.isEmpty
        case .pending: return pendingRounds.isEmpty
        case .past: return pastRounds.isEmpty
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

        async let hostingRounds = loadHostingRounds(dateRange: dateRange)
        async let requestedRounds = loadRequestedRounds(dateRange: dateRange)
        async let invitedRounds = loadInvitedRounds()

        let (hosting, requested, invited) = await (hostingRounds, requestedRounds, invitedRounds)

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

            if currentUserProfile == nil, let uid = currentUid() {
                currentUserProfile = try? await profileRepository.fetchPublicProfile(uid: uid)
            }

            for index in rounds.indices {
                guard let roundId = rounds[index].id else { continue }
                let members = try? await roundsRepository.fetchMembers(roundId: roundId)
                let pendingCount = members?.filter { $0.status == .requested }.count ?? 0
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
                    inviterName: nil,
                    inviterPhotoURL: nil
                )
            }
        } catch {
            print("Failed to load hosting rounds: \(error)")
            if errorMessage == nil { errorMessage = error.localizedDescription }
            return []
        }
    }

    private func loadRequestedRounds(dateRange: DateRangeOption) async -> [ActivityRoundItem] {
        do {
            let allRequests = try await activityService.fetchRequestedRounds(dateRange: dateRange)
            let requests = allRequests.filter { $0.status != .invited }

            let hostUids = Set(requests.map { $0.round.hostUid })
            let hostProfiles = await loadProfiles(for: hostUids)

            await preloadProfileImages(for: Array(hostProfiles.values))

            return requests.map { request in
                ActivityRoundItem(
                    round: request.round,
                    role: .participating,
                    status: request.status,
                    requestedAt: request.requestedAt,
                    invitedAt: nil,
                    hostProfile: hostProfiles[request.round.hostUid],
                    inviterName: nil,
                    inviterPhotoURL: nil
                )
            }
        } catch {
            print("Failed to load requested rounds: \(error)")
            if errorMessage == nil { errorMessage = error.localizedDescription }
            return []
        }
    }

    private func loadInvitedRounds() async -> [ActivityRoundItem] {
        do {
            let rounds = try await roundsRepository.fetchInvitedRounds()
            var items: [ActivityRoundItem] = []

            for round in rounds {
                guard let roundId = round.id else { continue }

                let member = try? await roundsRepository.fetchMembershipStatus(roundId: roundId)
                let hostProfile = try? await profileRepository.fetchPublicProfile(uid: round.hostUid)

                var inviterName: String?
                var inviterPhotoURL: String?
                if let invitedBy = member?.invitedBy {
                    let inviterProfile = try? await profileRepository.fetchPublicProfile(uid: invitedBy)
                    inviterName = inviterProfile?.nickname
                    inviterPhotoURL = inviterProfile?.photoUrls.first
                }

                items.append(ActivityRoundItem(
                    round: round,
                    role: .participating,
                    status: .invited,
                    requestedAt: nil,
                    invitedAt: member?.createdAt,
                    hostProfile: hostProfile,
                    inviterName: inviterName,
                    inviterPhotoURL: inviterPhotoURL
                ))
            }

            let profiles = items.compactMap { $0.hostProfile }
            await preloadProfileImages(for: profiles)

            return items
        } catch {
            print("Failed to load invited rounds: \(error)")
            if errorMessage == nil { errorMessage = error.localizedDescription }
            return []
        }
    }

    // MARK: - Invite Actions

    func acceptInvite(roundId: String) async {
        do {
            try await roundsRepository.acceptInvite(roundId: roundId)
            allRounds.removeAll { $0.round.id == roundId && $0.status == .invited }
        } catch {
            print("Failed to accept invite: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(roundId: String) async {
        do {
            try await roundsRepository.declineInvite(roundId: roundId)
            allRounds.removeAll { $0.round.id == roundId && $0.status == .invited }
        } catch {
            print("Failed to decline invite: \(error)")
            errorMessage = error.localizedDescription
        }
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
                if let profile = profile { profiles[uid] = profile }
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

        let pipeline = ImagePipeline.shared
        await withTaskGroup(of: Void.self) { group in
            for url in photoURLs {
                group.addTask {
                    _ = try? await pipeline.image(for: url)
                }
            }
        }
    }
}
