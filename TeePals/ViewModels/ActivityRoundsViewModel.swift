import Foundation
import UIKit

/// ViewModel for the Activity segment (Hosting + Participating + Invited rounds).
@MainActor
final class ActivityRoundsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let activityService: ActivityRoundsService
    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var hostingRounds: [Round] = []
    @Published var requestedRounds: [RoundRequest] = []
    @Published var invitedRounds: [Round] = []
    @Published var memberRecords: [String: RoundMember] = [:]  // roundId -> member record
    @Published var inviterProfiles: [String: PublicProfile] = [:]  // uid -> profile
    @Published var hostProfiles: [String: PublicProfile] = [:]
    @Published var currentUserProfile: PublicProfile?

    @Published var isLoadingHosting = false // Start false, set true only when loading
    @Published var isLoadingRequested = false
    @Published var isLoadingInvited = false
    @Published var errorMessage: String?

    @Published private(set) var hasLoadedOnce = false // Track if we've loaded before

    // Computed property: show skeleton until first load completes
    var shouldShowSkeleton: Bool {
        !hasLoadedOnce
    }
    
    var isLoading: Bool {
        isLoadingHosting || isLoadingRequested || isLoadingInvited
    }

    var isEmpty: Bool {
        hostingRounds.isEmpty && requestedRounds.isEmpty && invitedRounds.isEmpty && !isLoading && hasLoadedOnce
    }

    var hasHostingRounds: Bool {
        !hostingRounds.isEmpty
    }

    var hasRequestedRounds: Bool {
        !requestedRounds.isEmpty
    }

    var hasInvitedRounds: Bool {
        !invitedRounds.isEmpty
    }

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
    
    // MARK: - Load Data

    func loadActivity(dateRange: DateRangeOption = .next30) async {
        // Skip if already loaded once (prevents redundant loads on tab switches)
        guard !hasLoadedOnce else { return }

        // Skip if currently loading
        guard !isLoading else { return }

        errorMessage = nil

        // Ensure hasLoadedOnce is set even if loading is interrupted
        defer { hasLoadedOnce = true }

        // Load all three sections concurrently
        async let hostingTask: () = loadHostingRounds(dateRange: dateRange)
        async let requestedTask: () = loadRequestedRounds(dateRange: dateRange)
        async let invitedTask: () = loadInvitedRounds()

        await hostingTask
        await requestedTask
        await invitedTask
    }

    func refresh(dateRange: DateRangeOption = .next30) async {
        // Skip if currently loading to prevent race conditions
        guard !isLoading else { return }

        // Allow refresh even if already loaded
        hasLoadedOnce = false
        await loadActivity(dateRange: dateRange)
    }
    
    // MARK: - Private Loading
    
    private func loadHostingRounds(dateRange: DateRangeOption) async {
        // Only show skeleton if: first load OR we have cached data
        let shouldShowSkeleton = !hasLoadedOnce || !hostingRounds.isEmpty
        if shouldShowSkeleton {
            isLoadingHosting = true
        }
        defer { isLoadingHosting = false }

        do {
            hostingRounds = try await activityService.fetchHostingRounds(dateRange: dateRange)

            // Load current user's profile for hosting rounds
            if let uid = currentUid(), currentUserProfile == nil {
                currentUserProfile = try? await profileRepository.fetchPublicProfile(uid: uid)
            }
        } catch {
            print("Failed to load hosting rounds: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadRequestedRounds(dateRange: DateRangeOption) async {
        // Only show skeleton if: first load OR we have cached data
        let shouldShowSkeleton = !hasLoadedOnce || !requestedRounds.isEmpty
        if shouldShowSkeleton {
            isLoadingRequested = true
        }
        defer { isLoadingRequested = false }

        do {
            let fetchedRounds = try await activityService.fetchRequestedRounds(dateRange: dateRange)

            // Load profiles before showing rounds (everything appears together)
            let hostUids = Set(fetchedRounds.map { $0.round.hostUid })
            await loadProfiles(for: hostUids)

            // Preload profile images into cache
            await preloadProfileImages()

            // Show rounds with profiles and images loaded
            requestedRounds = fetchedRounds
        } catch {
            print("Failed to load requested rounds: \(error)")
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadInvitedRounds() async {
        // Only show skeleton if: first load OR we have cached data
        let shouldShowSkeleton = !hasLoadedOnce || !invitedRounds.isEmpty
        if shouldShowSkeleton {
            isLoadingInvited = true
        }
        defer { isLoadingInvited = false }

        do {
            let fetchedRounds = try await roundsRepository.fetchInvitedRounds()

            // Fetch member records and inviter profiles before showing rounds (everything appears together)
            await fetchMemberRecordsAndInviters(for: fetchedRounds)

            // Preload profile images into cache (including inviter photos)
            await preloadProfileImages()

            // Show rounds with profiles and images loaded
            invitedRounds = fetchedRounds
        } catch {
            print("Failed to load invited rounds: \(error)")
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Invited Actions

    func acceptInvite(roundId: String) async {
        do {
            try await roundsRepository.acceptInvite(roundId: roundId)

            // Remove from invited list
            invitedRounds.removeAll { $0.id == roundId }
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
            invitedRounds.removeAll { $0.id == roundId }
            memberRecords.removeValue(forKey: roundId)
        } catch {
            print("Failed to decline invite: \(error)")
            errorMessage = error.localizedDescription
        }
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

    private func loadProfiles(for uids: Set<String>) async {
        // Filter out UIDs we already have
        let uidsToFetch = uids.filter { hostProfiles[$0] == nil }
        guard !uidsToFetch.isEmpty else { return }

        // Fetch all profiles in parallel
        let profiles = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in uidsToFetch {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var result: [String: PublicProfile] = [:]
            for await (uid, profile) in group {
                if let profile = profile {
                    result[uid] = profile
                }
            }
            return result
        }

        // Update all at once to prevent flickering
        hostProfiles.merge(profiles) { _, new in new }
    }

    private func preloadProfileImages() async {
        // Extract all photo URLs from loaded profiles (including currentUserProfile, hosts, and inviters)
        var photoURLs: [URL] = []

        // Add current user's photo
        if let urlString = currentUserProfile?.photoUrls.first, let url = URL(string: urlString) {
            photoURLs.append(url)
        }

        // Add host photos
        let hostPhotos = hostProfiles.values.compactMap { profile -> URL? in
            guard let urlString = profile.photoUrls.first else { return nil }
            return URL(string: urlString)
        }
        photoURLs.append(contentsOf: hostPhotos)

        // Add inviter photos
        let inviterPhotos = inviterProfiles.values.compactMap { profile -> URL? in
            guard let urlString = profile.photoUrls.first else { return nil }
            return URL(string: urlString)
        }
        photoURLs.append(contentsOf: inviterPhotos)

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

    // MARK: - Helpers

    func hostProfile(for round: Round) -> PublicProfile? {
        hostProfiles[round.hostUid]
    }

    func inviterName(for roundId: String) -> String? {
        guard let member = memberRecords[roundId],
              let invitedBy = member.invitedBy,
              let profile = inviterProfiles[invitedBy] else {
            return nil
        }
        return profile.nickname
    }
}

