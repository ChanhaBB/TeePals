import Foundation

/// ViewModel for Round Detail screen.
@MainActor
final class RoundDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies

    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let chatRepository: ChatRepository?
    private let shareLinkService: ShareLinkServiceProtocol
    private let currentUid: () -> String?
    
    // MARK: - State
    
    @Published var round: Round?
    @Published var members: [RoundMember] = []
    @Published var memberProfiles: [String: PublicProfile] = [:]
    @Published var hostProfile: PublicProfile?
    @Published var myMembership: RoundMember?
    
    @Published var isLoading = false
    @Published var isActioning = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Share state
    @Published var showShareSheet = false
    @Published var shareURL: URL?
    @Published var isGeneratingLink = false

    let roundId: String
    
    // MARK: - Init
    
    init(
        roundId: String,
        roundsRepository: RoundsRepository,
        profileRepository: ProfileRepository,
        chatRepository: ChatRepository? = nil,
        shareLinkService: ShareLinkServiceProtocol,
        currentUid: @escaping () -> String?
    ) {
        self.roundId = roundId
        self.roundsRepository = roundsRepository
        self.profileRepository = profileRepository
        self.chatRepository = chatRepository
        self.shareLinkService = shareLinkService
        self.currentUid = currentUid
    }
    
    // MARK: - Computed Properties
    
    var isHost: Bool {
        guard let uid = currentUid(), let round = round else { return false }
        return round.hostUid == uid
    }
    
    var isMember: Bool {
        myMembership?.status == .accepted
    }
    
    var hasRequested: Bool {
        myMembership?.status == .requested
    }
    
    var isInvited: Bool {
        myMembership?.status == .invited
    }
    
    var canJoin: Bool {
        guard let round = round else { return false }
        return !isHost && !isMember && !hasRequested && !round.isFull && round.status == .open
    }
    
    var acceptedMembers: [RoundMember] {
        members.filter { $0.status == .accepted }
    }
    
    var pendingRequests: [RoundMember] {
        members.filter { $0.status == .requested }
    }
    
    var invitedMembers: [RoundMember] {
        members.filter { $0.status == .invited }
    }

    var canInvite: Bool {
        // Can invite if you're the host OR an accepted member
        isHost || isMember
    }

    var canShare: Bool {
        // Can share if you're the host OR an accepted member, and round is public
        guard let round = round else { return false }
        return (isHost || isMember) && round.visibility == .public
    }

    // MARK: - Share Actions

    func generateShareLink() async {
        guard let round = round else {
            errorMessage = "Round not found"
            return
        }

        isGeneratingLink = true
        defer { isGeneratingLink = false }

        do {
            shareURL = try await shareLinkService.createRoundInviteLink(
                roundId: roundId,
                round: round,
                inviterUid: currentUid()
            )
            showShareSheet = true
        } catch {
            errorMessage = "Failed to create share link. Please try again."
            print("Failed to generate share link: \(error)")
        }
    }

    func shareMessage() -> String {
        guard let round = round else { return "" }

        // Format date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let dateString = round.displayTeeTime.map { dateFormatter.string(from: $0) } ?? "TBD"
        let timeString = round.displayTeeTime.map { timeFormatter.string(from: $0) } ?? "TBD"

        return """
        Join my round at \(round.displayCourseName)!
        \(round.displayCityLabel) • \(dateString) at \(timeString)
        """
    }

    // MARK: - Load Data
    
    func loadRound() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load core data in parallel
            async let roundData = roundsRepository.fetchRound(id: roundId)
            async let membersData = roundsRepository.fetchMembers(roundId: roundId)
            async let membershipData = roundsRepository.fetchMembershipStatus(roundId: roundId)

            // Wait for core data
            let fetchedRound = try await roundData
            let fetchedMembers = try await membersData
            let fetchedMembership = try await membershipData

            guard let fetchedRound = fetchedRound else {
                errorMessage = "Round not found"
                isLoading = false
                return
            }

            // Fetch all profiles in parallel (host + all members)
            let allUids = Set([fetchedRound.hostUid] + fetchedMembers.map { $0.uid })
            let profileResults = await withTaskGroup(of: (String, PublicProfile?).self) { group in
                for uid in allUids {
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

            // Update UI once with all data (prevents flickering)
            round = fetchedRound
            members = fetchedMembers
            myMembership = fetchedMembership
            hostProfile = profileResults[fetchedRound.hostUid]
            memberProfiles = profileResults

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func refresh() async {
        await loadRound()
    }
    
    /// Directly update the local round state (used after editing).
    func updateRound(_ updatedRound: Round) {
        self.round = updatedRound
    }
    
    // MARK: - Actions
    
    func requestToJoin() async {
        guard let round = round, let uid = currentUid() else { return }

        errorMessage = nil

        if round.joinPolicy == .instant {
            // For instant join, show loading since it's a bigger state change
            isActioning = true

            do {
                try await roundsRepository.joinRound(roundId: roundId)
                successMessage = "You've joined the round!"
                await refresh()

                // Auto-dismiss success message after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                successMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isActioning = false
        } else {
            // For request, use optimistic UI
            // Optimistically create pending membership
            myMembership = RoundMember(
                uid: uid,
                role: .member,
                status: .requested
            )
            successMessage = "Request sent!"

            // Make API call in background
            do {
                try await roundsRepository.requestToJoin(roundId: roundId)

                // Success - refresh to get latest data
                await refresh()

                // Auto-dismiss success message after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                successMessage = nil
            } catch {
                // Revert optimistic update on failure
                myMembership = nil
                successMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func leaveRound() async {
        isActioning = true
        errorMessage = nil

        // Get current user's nickname before leaving
        let myNickname = currentUid().flatMap { memberProfiles[$0]?.nickname } ?? "A member"

        do {
            // Send system message BEFORE leaving (while we still have write permission)
            if let chatRepo = chatRepository {
                try? await chatRepo.sendSystemMessage(
                    roundId: roundId,
                    template: .memberLeft(nickname: myNickname)
                )
            }

            // Now leave the round
            try await roundsRepository.leaveRound(roundId: roundId)

            successMessage = "You've left the round"
            await refresh()

            // Auto-dismiss success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            successMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    func cancelRequest() async {
        // Save current state for rollback if needed
        let previousMembership = myMembership

        // Optimistically update UI immediately
        myMembership = nil
        successMessage = "Request canceled"

        // Make API call in background
        do {
            try await roundsRepository.leaveRound(roundId: roundId)

            // Success - refresh to get latest data
            await refresh()

            // Auto-dismiss success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            successMessage = nil
        } catch {
            // Revert optimistic update on failure
            myMembership = previousMembership
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }
    
    func acceptMember(_ memberUid: String) async {
        isActioning = true
        errorMessage = nil
        
        do {
            try await roundsRepository.acceptMember(roundId: roundId, memberUid: memberUid)
            
            // Send system message announcing the new member
            if let chatRepo = chatRepository {
                let nickname = memberProfiles[memberUid]?.nickname ?? "A new member"
                try? await chatRepo.sendSystemMessage(
                    roundId: roundId,
                    template: .memberAccepted(nickname: nickname)
                )
            }
            
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isActioning = false
    }
    
    func declineMember(_ memberUid: String) async {
        isActioning = true
        errorMessage = nil
        do {
            try await roundsRepository.declineMember(roundId: roundId, memberUid: memberUid)
            await refresh()
        } catch { errorMessage = error.localizedDescription }
        isActioning = false
    }
    
    func removeMember(_ memberUid: String) async {
        isActioning = true
        errorMessage = nil
        let nickname = memberProfiles[memberUid]?.nickname ?? "A member"
        do {
            try await roundsRepository.removeMember(roundId: roundId, memberUid: memberUid)
            if let chatRepo = chatRepository {
                try? await chatRepo.sendSystemMessage(roundId: roundId, template: .memberRemoved(nickname: nickname))
            }
            await refresh()
        } catch { errorMessage = error.localizedDescription }
        isActioning = false
    }
    
    func cancelRound() async {
        isActioning = true
        errorMessage = nil
        do {
            try await roundsRepository.cancelRound(id: roundId)
            successMessage = "Round canceled"
            await refresh()
        } catch { errorMessage = error.localizedDescription }
        isActioning = false
    }
}

