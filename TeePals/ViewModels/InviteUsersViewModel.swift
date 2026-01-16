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
    @Published var memberStatus: [String: MemberStatus] = [:]  // Track membership status
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var isInviting: Set<String> = []  // Track which users are being invited
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var isEmpty: Bool {
        followingUsers.isEmpty && !isLoading
    }

    var filteredUsers: [PublicProfile] {
        if searchText.isEmpty {
            return followingUsers
        }
        return followingUsers.filter { user in
            user.nickname.localizedCaseInsensitiveContains(searchText)
        }
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

            // Sort: non-members first, then by nickname within each group
            followingUsers = profileResults.sorted { lhs, rhs in
                let lhsIsMember = statusMap[lhs.id ?? ""] != nil
                let rhsIsMember = statusMap[rhs.id ?? ""] != nil

                if lhsIsMember != rhsIsMember {
                    return !lhsIsMember  // Non-members first
                }
                return lhs.nickname < rhs.nickname
            }
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
