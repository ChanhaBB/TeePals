import Foundation
import CoreLocation

/// ViewModel for the home dashboard.
/// Handles nearby rounds, user profile, and course photo loading.
/// Schedule/invite/pending data comes from the shared ActivityRoundsViewModelV2.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Dependencies

    private let roundsSearchService: RoundsSearchService
    private let profileRepository: ProfileRepository
    private let coursePhotoService: CoursePhotoService
    private let currentUid: () -> String?

    // MARK: - State

    @Published private(set) var nextRoundPhotoURL: URL?
    @Published private(set) var nearbyRounds: [Round] = []
    @Published private(set) var hostProfiles: [String: PublicProfile] = [:]
    @Published private(set) var userProfile: PublicProfile?

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Init

    init(
        roundsSearchService: RoundsSearchService,
        profileRepository: ProfileRepository,
        coursePhotoService: CoursePhotoService,
        currentUid: @escaping () -> String?
    ) {
        self.roundsSearchService = roundsSearchService
        self.profileRepository = profileRepository
        self.coursePhotoService = coursePhotoService
        self.currentUid = currentUid
    }

    // MARK: - Public Methods

    /// Load dashboard data (profile + nearby rounds).
    func loadDashboard() async {
        guard let uid = currentUid() else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let profile = try await profileRepository.fetchPublicProfile(uid: uid) else {
                errorMessage = "Profile not found"
                isLoading = false
                return
            }
            self.userProfile = profile

            let filter = RoundsSearchFilter(
                center: profile.primaryLocation,
                radiusMiles: 30,
                dateRange: .next30
            )
            let nearbyPage = try await roundsSearchService.searchRounds(filter: filter, page: nil)

            self.nearbyRounds = Array(nearbyPage.items.prefix(3))
            await fetchHostProfiles(for: self.nearbyRounds)

            isLoading = false
        } catch {
            errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Load course photo for the hero card (called after activity data is available).
    func loadCoursePhoto(for round: Round) async {
        guard let course = round.chosenCourse ?? round.courseCandidates.first else {
            self.nextRoundPhotoURL = nil
            return
        }
        self.nextRoundPhotoURL = await coursePhotoService.fetchPhotoURL(for: course)
    }

    func refresh() async {
        await loadDashboard()
    }

    // MARK: - Private Helpers

    private func fetchHostProfiles(for rounds: [Round]) async {
        let hostUids = Set(rounds.map { $0.hostUid })

        await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in hostUids {
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

            self.hostProfiles = profiles
        }
    }
}
