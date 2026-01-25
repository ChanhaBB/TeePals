import Foundation

/// ViewModel for viewing another user's public profile.
@MainActor
final class OtherUserProfileViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let socialRepository: SocialRepository
    private let currentUid: () -> String?
    
    // MARK: - State
    
    @Published var profile: PublicProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isFollowing = false
    @Published var isMutualFollow = false
    @Published var isFollowedByThem = false

    let uid: String
    
    // MARK: - Init
    
    init(
        uid: String,
        profileRepository: ProfileRepository,
        socialRepository: SocialRepository,
        currentUid: @escaping () -> String?
    ) {
        self.uid = uid
        self.profileRepository = profileRepository
        self.socialRepository = socialRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Computed
    
    var isOwnProfile: Bool {
        currentUid() == uid
    }
    
    var displayName: String {
        profile?.nickname ?? "User"
    }
    
    // MARK: - Load
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load all data in parallel to prevent UI flickering
            async let profileData = profileRepository.fetchPublicProfile(uid: uid)
            async let followerCountData = socialRepository.getFollowerCount(uid: uid)
            async let followingCountData = socialRepository.getFollowingCount(uid: uid)

            // Load follow status in parallel if authenticated
            let followStatusData: (isFollowing: Bool, isMutual: Bool, isFollowedBy: Bool)
            if let _ = currentUid() {
                async let isFollowingData = socialRepository.isFollowing(targetUid: uid)
                async let isMutualFollowData = socialRepository.isMutualFollow(targetUid: uid)
                async let isFollowedByData = socialRepository.isFollowedBy(targetUid: uid)
                followStatusData = try await (isFollowingData, isMutualFollowData, isFollowedByData)
            } else {
                followStatusData = (false, false, false)
            }

            // Wait for all data to complete
            let fetchedProfile = try await profileData
            let fetchedFollowerCount = try await followerCountData
            let fetchedFollowingCount = try await followingCountData

            // Update UI once with all data (prevents flickering)
            profile = fetchedProfile
            followerCount = fetchedFollowerCount
            followingCount = fetchedFollowingCount
            isFollowing = followStatusData.isFollowing
            isMutualFollow = followStatusData.isMutual
            isFollowedByThem = followStatusData.isFollowedBy

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Actions
    
    func toggleFollow() async {
        guard let _ = currentUid(), !isOwnProfile else { return }

        // Optimistic update: change UI immediately
        let wasFollowing = isFollowing
        let wasFollowerCount = followerCount

        if isFollowing {
            // Unfollow: update UI instantly
            isFollowing = false
            isMutualFollow = false
            followerCount = max(0, followerCount - 1)

            do {
                try await socialRepository.unfollow(targetUid: uid)
            } catch {
                // Revert on error (will correct on refresh)
                isFollowing = wasFollowing
                followerCount = wasFollowerCount
            }
        } else {
            // Follow: update UI instantly
            isFollowing = true
            if isFollowedByThem {
                isMutualFollow = true
            }
            followerCount += 1

            do {
                try await socialRepository.follow(targetUid: uid)
            } catch {
                // Revert on error (will correct on refresh)
                isFollowing = wasFollowing
                followerCount = wasFollowerCount
            }
        }
    }
}

