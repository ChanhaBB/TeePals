import Foundation
import UIKit

/// ViewModel for invited rounds (rounds where user received an invitation).
@MainActor
final class InvitedRoundsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var rounds: [Round] = []
    @Published var memberRecords: [String: RoundMember] = [:]  // roundId -> member record
    @Published var inviterProfiles: [String: PublicProfile] = [:]  // uid -> profile
    @Published var isLoading = false // Start as false, set true when actually loading
    @Published var errorMessage: String?

    private var hasLoadedOnce = false // Track if we've loaded before

    var isEmpty: Bool {
        rounds.isEmpty && !isLoading && hasLoadedOnce
    }

    // MARK: - Init

    init(
        roundsRepository: RoundsRepository,
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundsRepository = roundsRepository
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }

    // MARK: - Load Data

    func loadRounds() async {
        // Only show skeleton if: first load OR we have cached data
        let shouldShowSkeleton = !hasLoadedOnce || !rounds.isEmpty
        if shouldShowSkeleton {
            isLoading = true
        }
        errorMessage = nil

        do {
            let fetchedRounds = try await roundsRepository.fetchInvitedRounds()

            // Fetch member records and inviter profiles before showing rounds (everything appears together)
            await fetchMemberRecordsAndInviters(for: fetchedRounds)

            // Preload profile images into cache
            await preloadProfileImages()

            // Show rounds with profiles and images loaded
            rounds = fetchedRounds
        } catch {
            print("Failed to load invited rounds: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
        hasLoadedOnce = true
    }

    func refresh() async {
        await loadRounds()
    }

    // MARK: - Actions

    func acceptInvite(roundId: String) async {
        do {
            try await roundsRepository.acceptInvite(roundId: roundId)

            // Remove from invited list
            rounds.removeAll { $0.id == roundId }
            memberRecords.removeValue(forKey: roundId)
        } catch {
            print("Failed to accept invite: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(roundId: String) async {
        do {
            try await roundsRepository.declineInvite(roundId: roundId)

            // Remove from invited list
            rounds.removeAll { $0.id == roundId }
            memberRecords.removeValue(forKey: roundId)
        } catch {
            print("Failed to decline invite: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    func inviterName(for roundId: String) -> String? {
        guard let member = memberRecords[roundId],
              let invitedBy = member.invitedBy,
              let profile = inviterProfiles[invitedBy] else {
            return nil
        }
        return profile.nickname
    }

    // MARK: - Private Helpers

    private func fetchMemberRecordsAndInviters(for rounds: [Round]) async {
        // Fetch member records for all invited rounds
        let memberResults = await withTaskGroup(of: (String, RoundMember?).self) { group in
            for round in rounds {
                guard let roundId = round.id else { continue }
                group.addTask {
                    let member = try? await self.roundsRepository.fetchMembershipStatus(roundId: roundId)
                    return (roundId, member)
                }
            }

            var records: [String: RoundMember] = [:]
            for await (roundId, member) in group {
                if let member = member {
                    records[roundId] = member
                }
            }
            return records
        }

        memberRecords = memberResults

        // Extract unique inviter UIDs
        let inviterUids = Set(memberRecords.values.compactMap { $0.invitedBy })

        // Fetch all inviter profiles in parallel
        let profileResults = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in inviterUids {
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

        inviterProfiles = profileResults
    }

    private func preloadProfileImages() async {
        // Extract all photo URLs from inviter profiles
        let photoURLs = inviterProfiles.values.compactMap { profile -> URL? in
            guard let urlString = profile.photoUrls.first else { return nil }
            return URL(string: urlString)
        }

        guard !photoURLs.isEmpty else { return }

        // Download all images in parallel and cache them
        await withTaskGroup(of: Void.self) { group in
            for url in photoURLs {
                group.addTask {
                    // Check if already cached
                    if ImageCache.shared.get(for: url) != nil {
                        return
                    }

                    // Download and cache
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            ImageCache.shared.set(image, for: url)
                        }
                    } catch {
                        // Silently fail - image will show placeholder
                    }
                }
            }
        }
    }
}
