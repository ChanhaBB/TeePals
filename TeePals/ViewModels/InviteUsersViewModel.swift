import Foundation

/// ViewModel for inviting users to a round.
/// Shows list of users you follow and allows sending invitations.
@MainActor
final class InviteUsersViewModel: ObservableObject {

    // MARK: - Dependencies

    private let roundId: String
    private let roundsRepository: RoundsRepository
    private let socialRepository: SocialRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var followingUsers: [PublicProfile] = []
    @Published var sortedFollowingUsers: [PublicProfile] = []  // Stable sorted list
    @Published var suggestedUsers: [PublicProfile] = []        // Frozen snapshot set at load time
    @Published var memberStatus: [String: MemberStatus] = [:]  // Track membership status
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var isInviting: Set<String> = []  // Track which users are being invited
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var currentUserProfile: PublicProfile?

    var isEmpty: Bool {
        followingUsers.isEmpty && !isLoading
    }

    var filteredUsers: [PublicProfile] {
        if searchText.isEmpty {
            return sortedFollowingUsers
        }
        return sortedFollowingUsers.filter { user in
            user.nickname.localizedCaseInsensitiveContains(searchText)
        }
    }

    var allFollowingUsers: [PublicProfile] {
        guard searchText.isEmpty else {
            return filteredUsers
        }

        // Return stable sorted list (no re-sorting during session)
        return sortedFollowingUsers
    }

    // MARK: - Init

    init(
        roundId: String,
        roundsRepository: RoundsRepository,
        socialRepository: SocialRepository,
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundId = roundId
        self.roundsRepository = roundsRepository
        self.socialRepository = socialRepository
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }

    // MARK: - Load Data

    func loadFollowing() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load current user profile for distance calculation
            if let uid = currentUid() {
                currentUserProfile = try? await profileRepository.fetchPublicProfile(uid: uid)
            }

            // Fetch following UIDs
            let followingUids = try await socialRepository.getFollowing()

            // Fetch members of this round to track their status
            let members = try await roundsRepository.fetchMembers(roundId: roundId)

            // Build status map for all members
            var statusMap: [String: MemberStatus] = [:]
            for member in members {
                statusMap[member.uid] = member.status
            }
            memberStatus = statusMap

            // Fetch profiles for ALL following users (including existing members)
            let profileResults = await withTaskGroup(of: (String, PublicProfile?).self) { group in
                for uid in followingUids {
                    group.addTask {
                        let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                        return (uid, profile)
                    }
                }

                var profiles: [PublicProfile] = []
                for await (_, profile) in group {
                    if let profile = profile {
                        profiles.append(profile)
                    }
                }
                return profiles
            }

            // Filter out members (status == .accepted) - we only want to show people we can invite
            let nonMembers = profileResults.filter { profile in
                let status = statusMap[profile.id ?? ""]
                return status != .accepted
            }

            // Sort once on load: invited first, then candidates (alphabetically)
            let sorted = nonMembers.sorted { lhs, rhs in
                let lhsStatus = statusMap[lhs.id ?? ""]
                let rhsStatus = statusMap[rhs.id ?? ""]

                let lhsIsInvited = lhsStatus == .invited
                let rhsIsInvited = rhsStatus == .invited

                if lhsIsInvited != rhsIsInvited {
                    return lhsIsInvited  // Invited first
                }
                return lhs.nickname < rhs.nickname
            }

            // Store all following users and stable sorted list
            followingUsers = profileResults
            sortedFollowingUsers = sorted

            // Build suggested snapshot: top 5 closest uninvited candidates.
            // Frozen at load time so rows don't disappear mid-session when tapping Invite.
            // On next open loadFollowing() runs fresh and rebuilds with current Firestore state.
            suggestedUsers = buildSuggested(from: sorted, statusMap: statusMap)
        } catch {
            print("Failed to load following users: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Actions

    func inviteUser(_ uid: String) async {
        // Allow inviting if no status OR if status allows re-invitation
        let status = memberStatus[uid]
        let canInvite = status == nil || canBeReinvited(status!)
        guard canInvite, !isInviting.contains(uid) else { return }

        isInviting.insert(uid)
        errorMessage = nil
        successMessage = nil

        do {
            try await roundsRepository.inviteMember(roundId: roundId, targetUid: uid)

            // Mark as invited
            memberStatus[uid] = .invited
            successMessage = "Invitation sent!"

            // Clear success message after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                successMessage = nil
            }
        } catch {
            print("Failed to invite user: \(error)")
            errorMessage = error.localizedDescription
        }

        isInviting.remove(uid)
    }

    func getMemberStatus(_ uid: String) -> MemberStatus? {
        memberStatus[uid]
    }

    func isInvitingUser(_ uid: String) -> Bool {
        isInviting.contains(uid)
    }

    // MARK: - Helpers

    private func buildSuggested(from users: [PublicProfile], statusMap: [String: MemberStatus]) -> [PublicProfile] {
        guard let currentProfile = currentUserProfile else { return [] }

        // Only uninvited candidates — excludes .invited so fresh open always shows new suggestions
        let candidates = users.filter { user in
            let status = statusMap[user.id ?? ""]
            return status == nil || canBeReinvited(status!)
        }

        let userLocation = currentProfile.primaryLocation
        let byDistance = candidates.sorted { lhs, rhs in
            let ld = DistanceUtil.haversineMiles(
                lat1: userLocation.latitude, lng1: userLocation.longitude,
                lat2: lhs.primaryLocation.latitude, lng2: lhs.primaryLocation.longitude
            )
            let rd = DistanceUtil.haversineMiles(
                lat1: userLocation.latitude, lng1: userLocation.longitude,
                lat2: rhs.primaryLocation.latitude, lng2: rhs.primaryLocation.longitude
            )
            return ld < rd
        }

        return Array(byDistance.prefix(5))
    }

    private func canBeReinvited(_ status: MemberStatus) -> Bool {
        // Users with these statuses can be re-invited
        switch status {
        case .removed, .declined, .left:
            return true
        case .accepted, .invited, .requested:
            return false
        }
    }
}
