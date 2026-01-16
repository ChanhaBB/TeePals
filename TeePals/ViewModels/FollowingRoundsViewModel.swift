import Foundation
import UIKit

/// ViewModel for the Following segment (rounds from followed users).
@MainActor
final class FollowingRoundsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let followingService: FollowingRoundsService
    private let profileRepository: ProfileRepository
    private let socialRepository: SocialRepository
    
    // MARK: - State

    @Published var rounds: [Round] = []
    @Published var hostProfiles: [String: PublicProfile] = [:]
    @Published var followsBack: Set<String> = [] // Hosts who follow the user back

    @Published var isLoading = false // Start false, set true only when loading
    @Published var errorMessage: String?

    private var hasLoadedOnce = false // Track if we've loaded before

    // Computed property: show skeleton until first load completes
    var shouldShowSkeleton: Bool {
        !hasLoadedOnce
    }

    var isEmpty: Bool {
        rounds.isEmpty && !isLoading && hasLoadedOnce
    }
    
    var hasRounds: Bool {
        !rounds.isEmpty
    }
    
    // MARK: - Init
    
    init(
        followingService: FollowingRoundsService,
        profileRepository: ProfileRepository,
        socialRepository: SocialRepository
    ) {
        self.followingService = followingService
        self.profileRepository = profileRepository
        self.socialRepository = socialRepository
    }
    
    // MARK: - Load Data
    
    func loadRounds(dateRange: DateRangeOption = .next30) async {
        // Skip if already loaded once (prevents redundant loads on tab switches)
        guard !hasLoadedOnce else { return }

        // Skip if currently loading
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetchedRounds = try await followingService.fetchFollowingHostedRounds(dateRange: dateRange)

            // Load profiles and follow-back status before showing rounds (everything appears together)
            let hostUids = Set(fetchedRounds.map { $0.hostUid })
            await loadProfiles(for: hostUids)
            await checkFollowsBack(for: hostUids)

            // Preload profile images into cache
            await preloadProfileImages()

            // Show rounds with profiles and images loaded
            rounds = fetchedRounds

            hasLoadedOnce = true
        } catch {
            print("Failed to load following rounds: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refresh(dateRange: DateRangeOption = .next30) async {
        // Allow refresh even if already loaded
        hasLoadedOnce = false
        await loadRounds(dateRange: dateRange)
    }
    
    // MARK: - Private Helpers
    
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

    private func checkFollowsBack(for uids: Set<String>) async {
        // Fetch all follow-back statuses in parallel
        let followBackStatuses = await withTaskGroup(of: (String, Bool).self) { group in
            for uid in uids {
                group.addTask {
                    let followsUser = (try? await self.socialRepository.isFollowedBy(targetUid: uid)) ?? false
                    return (uid, followsUser)
                }
            }

            var result: Set<String> = []
            for await (uid, followsUser) in group {
                if followsUser {
                    result.insert(uid)
                }
            }
            return result
        }

        // Update all at once to prevent flickering
        followsBack = followBackStatuses
    }

    private func preloadProfileImages() async {
        // Extract all photo URLs from loaded profiles
        let photoURLs = hostProfiles.values.compactMap { profile -> URL? in
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

    // MARK: - Accessors

    func hostProfile(for round: Round) -> PublicProfile? {
        hostProfiles[round.hostUid]
    }
    
    func hostFollowsBack(_ round: Round) -> Bool {
        followsBack.contains(round.hostUid)
    }
}

