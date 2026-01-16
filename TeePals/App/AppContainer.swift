import Foundation
import FirebaseAuth
import Combine

/// Dependency injection container for the app.
/// Creates and provides repository instances and view models.
@MainActor
final class AppContainer: ObservableObject {
    
    // MARK: - Repositories (Singletons)
    
    private(set) lazy var profileRepository: ProfileRepository = {
        FirestoreProfileRepository()
    }()
    
    private(set) lazy var socialRepository: SocialRepository = {
        FirestoreSocialRepository()
    }()
    
    private(set) lazy var roundsRepository: RoundsRepository = {
        FirestoreRoundsRepository()
    }()
    
    // MARK: - Services (Singletons)
    
    private(set) lazy var storageService: StorageServiceProtocol = {
        StorageService()
    }()
    
    private(set) lazy var roundsSearchService: RoundsSearchService = {
        FirestoreGeoHashRoundsSearchService()
    }()
    
    private(set) lazy var activityRoundsService: ActivityRoundsService = {
        FirestoreActivityRoundsService()
    }()
    
    private(set) lazy var followingRoundsService: FollowingRoundsService = {
        FirestoreFollowingRoundsService(socialRepository: socialRepository)
    }()
    
    private(set) lazy var chatRepository: ChatRepository = {
        FirestoreChatRepository(profileRepository: profileRepository)
    }()
    
    private(set) lazy var postsRepository: PostsRepository = {
        FirestorePostsRepository(
            profileRepository: profileRepository,
            socialRepository: socialRepository
        )
    }()

    private(set) lazy var notificationsRepository: NotificationsRepository = {
        FirestoreNotificationsRepository()
    }()

    private(set) lazy var shareLinkService: ShareLinkServiceProtocol = {
        ShareLinkService()
    }()

    // MARK: - Coordinators (Singletons - shared across app)

    private(set) lazy var profileGateCoordinator: ProfileGateCoordinator = {
        ProfileGateCoordinator(
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }()

    // MARK: - ViewModels (Singletons - for tab-level state)

    @Published var notificationsViewModel: NotificationsViewModel? {
        didSet {
            // Forward objectWillChange from nested view model to container
            if let vm = notificationsViewModel {
                vm.objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }.store(in: &cancellables)
            }
        }
    }

    @Published var profileViewModel: ProfileViewModel? {
        didSet {
            // Forward objectWillChange from nested view model to container
            if let vm = profileViewModel {
                vm.objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }.store(in: &cancellables)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current User UID
    
    var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    func currentUidProvider() -> String? {
        currentUid
    }
    
    // MARK: - ViewModel Factories
    
    func makeProfileSetupViewModel() -> ProfileSetupViewModel {
        ProfileSetupViewModel(
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeProfileViewModel() -> ProfileViewModel {
        if let existing = profileViewModel {
            return existing
        }
        let vm = ProfileViewModel(
            profileRepository: profileRepository,
            socialRepository: socialRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
        Task { @MainActor in
            profileViewModel = vm
        }
        return vm
    }
    
    func makeProfileGateViewModel() -> ProfileGateViewModel {
        ProfileGateViewModel(
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeTier1OnboardingViewModel() -> Tier1OnboardingViewModel {
        Tier1OnboardingViewModel(
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeProfileEditViewModel() -> ProfileEditViewModel {
        ProfileEditViewModel(
            profileRepository: profileRepository,
            storageService: storageService,
            postsRepository: postsRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeCreateRoundViewModel() -> CreateRoundViewModel {
        CreateRoundViewModel(
            roundsRepository: roundsRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeRoundsListViewModel() -> RoundsListViewModel {
        RoundsListViewModel(
            roundsSearchService: roundsSearchService,
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeRoundDetailViewModel(roundId: String) -> RoundDetailViewModel {
        RoundDetailViewModel(
            roundId: roundId,
            roundsRepository: roundsRepository,
            profileRepository: profileRepository,
            chatRepository: chatRepository,
            shareLinkService: shareLinkService,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeOtherUserProfileViewModel(uid: String) -> OtherUserProfileViewModel {
        OtherUserProfileViewModel(
            uid: uid,
            profileRepository: profileRepository,
            socialRepository: socialRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeActivityRoundsViewModel() -> ActivityRoundsViewModel {
        ActivityRoundsViewModel(
            activityService: activityRoundsService,
            roundsRepository: roundsRepository,
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeFollowingRoundsViewModel() -> FollowingRoundsViewModel {
        FollowingRoundsViewModel(
            followingService: followingRoundsService,
            profileRepository: profileRepository,
            socialRepository: socialRepository
        )
    }
    
    func makeRoundChatViewModel(roundId: String) -> RoundChatViewModel {
        RoundChatViewModel(
            roundId: roundId,
            chatRepository: chatRepository,
            roundsRepository: roundsRepository,
            profileRepository: profileRepository,
            storageService: storageService,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    // MARK: - Phase 4: Social Layer ViewModels
    
    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(
            postsRepository: postsRepository,
            socialRepository: socialRepository,
            profileRepository: profileRepository,
            roundsRepository: roundsRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeCreatePostViewModel() -> CreatePostViewModel {
        CreatePostViewModel(
            postsRepository: postsRepository,
            roundsRepository: roundsRepository,
            storageService: storageService,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makePostDetailViewModel(postId: String) -> PostDetailViewModel {
        PostDetailViewModel(
            postId: postId,
            postsRepository: postsRepository,
            roundsRepository: roundsRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }
    
    func makeUserPostsViewModel(uid: String) -> UserPostsViewModel {
        UserPostsViewModel(
            targetUid: uid,
            postsRepository: postsRepository
        )
    }

    func makeInviteUsersViewModel(roundId: String) -> InviteUsersViewModel {
        InviteUsersViewModel(
            roundId: roundId,
            roundsRepository: roundsRepository,
            socialRepository: socialRepository,
            profileRepository: profileRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
    }

    // MARK: - Phase 5: Notifications

    func makeNotificationsViewModel() -> NotificationsViewModel {
        if let existing = notificationsViewModel {
            return existing
        }
        let vm = NotificationsViewModel(
            notificationsRepository: notificationsRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
        Task { @MainActor in
            notificationsViewModel = vm
            vm.startListening()
        }
        return vm
    }
}
