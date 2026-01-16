import Foundation

/// ViewModel for ProfileSetupView (Tier 1 setup, legacy).
/// Note: ProfileEditView/ProfileEditViewModel is preferred for editing.
@MainActor
final class ProfileSetupViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Public profile fields
    @Published var nickname = ""
    @Published var photoUrls: [String] = []
    @Published var gender: Gender?
    @Published var occupation = ""
    @Published var bio = ""
    @Published var primaryCityLabel = ""
    @Published var primaryLocation: GeoLocation?
    @Published var avgScore: Int?
    @Published var experienceLevel: ExperienceLevel?
    @Published var playsPerMonth: Int?
    @Published var skillLevel: SkillLevel?
    
    // Private profile fields
    @Published var birthDate: Date?
    
    // MARK: - Computed Properties
    
    /// Extracts birth year from birthDate for public profile (age calculation)
    var birthYear: Int? {
        guard let birthDate = birthDate else { return nil }
        return Calendar.current.component(.year, from: birthDate)
    }
    
    /// Validates that Tier 1 required fields are filled.
    /// Tier 1: nickname, primary location, birthDate, gender
    var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !primaryCityLabel.isEmpty &&
        primaryLocation != nil &&
        birthDate != nil &&
        gender != nil
    }
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Load Existing Profile
    
    func loadExistingProfile() async {
        guard let uid = currentUid() else {
            errorMessage = "Not signed in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Load public profile
            if let publicProfile = try await profileRepository.fetchPublicProfile(uid: uid) {
                nickname = publicProfile.nickname
                photoUrls = publicProfile.photoUrls
                gender = publicProfile.gender
                occupation = publicProfile.occupation ?? ""
                bio = publicProfile.bio ?? ""
                primaryCityLabel = publicProfile.primaryCityLabel
                primaryLocation = publicProfile.primaryLocation
                avgScore = publicProfile.avgScore
                experienceLevel = publicProfile.experienceLevel
                playsPerMonth = publicProfile.playsPerMonth
                skillLevel = publicProfile.skillLevel
            }
            
            // Load private profile
            if let privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid) {
                birthDate = parseBirthDate(privateProfile.birthDate)
            }
        } catch {
            if let repoError = error as? ProfileRepositoryError {
                switch repoError {
                case .notFound:
                    break // Expected for new users
                default:
                    errorMessage = repoError.localizedDescription
                }
            } else {
                errorMessage = "Failed to load profile"
            }
        }
    }
    
    // MARK: - Save Profile
    
    func saveProfile() async -> Bool {
        guard let uid = currentUid() else {
            errorMessage = "Not signed in"
            return false
        }
        
        guard let location = primaryLocation else {
            errorMessage = "Please set your location"
            return false
        }
        
        guard let birthDate = birthDate else {
            errorMessage = "Please enter your birth date"
            return false
        }
        
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmedNickname.isEmpty else {
            errorMessage = "Please enter a nickname"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let publicProfile = PublicProfile(
                id: uid,
                nickname: trimmedNickname,
                photoUrls: photoUrls,
                gender: gender,
                occupation: occupation.isEmpty ? nil : occupation,
                bio: bio.isEmpty ? nil : bio,
                primaryCityLabel: primaryCityLabel,
                primaryLocation: location,
                avgScore: avgScore,
                experienceLevel: experienceLevel,
                playsPerMonth: playsPerMonth,
                skillLevel: skillLevel,
                birthYear: birthYear
            )
            
            try await profileRepository.upsertPublicProfile(publicProfile)
            
            let privateProfile = PrivateProfile(
                id: uid,
                birthDate: formatBirthDate(birthDate)
            )
            
            try await profileRepository.upsertPrivateProfile(privateProfile)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Location Helper
    
    func setLocation(latitude: Double, longitude: Double, cityLabel: String) {
        primaryLocation = GeoLocation(latitude: latitude, longitude: longitude)
        primaryCityLabel = cityLabel
    }
    
    // MARK: - Private Helpers
    
    private func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseBirthDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
