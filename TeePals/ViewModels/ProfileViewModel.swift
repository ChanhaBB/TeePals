import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let socialRepository: SocialRepository
    private let currentUid: () -> String?
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var publicProfile: PublicProfile?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    
    // MARK: - Computed
    
    var hasProfile: Bool {
        publicProfile != nil
    }
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        socialRepository: SocialRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.socialRepository = socialRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Load Profile
    
    func loadProfile() async {
        guard let uid = currentUid() else {
            errorMessage = "Not signed in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Load profile and social counts concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchPublicProfile(uid: uid)
            }
            group.addTask {
                await self.fetchSocialCounts()
            }
        }
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
    
    private func fetchSocialCounts() async {
        do {
            async let followers = socialRepository.getFollowers()
            async let following = socialRepository.getFollowing()
            
            let (followersList, followingList) = try await (followers, following)
            followerCount = followersList.count
            followingCount = followingList.count
        } catch {
            // Social counts failing is non-critical, just log
            print("Failed to fetch social counts: \(error)")
        }
    }
    
    // MARK: - Refresh
    
    func refresh() async {
        await loadProfile()
    }
}

