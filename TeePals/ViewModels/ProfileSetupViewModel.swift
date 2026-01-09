import Foundation

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
    @Published var photoUrl: String?
    @Published var gender: Gender?
    @Published var occupation = ""
    @Published var bio = ""
    @Published var primaryCityLabel = ""
    @Published var primaryLocation: GeoLocation?
    @Published var avgScore18: Int?
    @Published var experienceYears: Int?
    @Published var playsPerMonth: Int?
    @Published var skillLevel: SkillLevel?
    
    // Private profile fields
    @Published var birthDate: Date?
    
    // MARK: - Computed Properties
    
    /// Computes age decade from birthDate for public profile
    var ageDecade: AgeDecade? {
        guard let birthDate = birthDate else { return nil }
        let age = calculateAge(from: birthDate)
        return ageDecadeFromAge(age)
    }
    
    /// Validates that required fields are filled
    var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !primaryCityLabel.isEmpty &&
        primaryLocation != nil &&
        birthDate != nil
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
                photoUrl = publicProfile.photoUrl
                gender = publicProfile.gender
                occupation = publicProfile.occupation ?? ""
                bio = publicProfile.bio ?? ""
                primaryCityLabel = publicProfile.primaryCityLabel
                primaryLocation = publicProfile.primaryLocation
                avgScore18 = publicProfile.avgScore18
                experienceYears = publicProfile.experienceYears
                playsPerMonth = publicProfile.playsPerMonth
                skillLevel = publicProfile.skillLevel
            }
            
            // Load private profile
            if let privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid) {
                birthDate = parseBirthDate(privateProfile.birthDate)
            }
        } catch {
            // If profiles don't exist, that's okay for setup
            // Only show error for actual failures
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
            // Build and save public profile
            let publicProfile = PublicProfile(
                id: uid,
                nickname: trimmedNickname,
                photoUrl: photoUrl,
                gender: gender,
                occupation: occupation.isEmpty ? nil : occupation,
                bio: bio.isEmpty ? nil : bio,
                primaryCityLabel: primaryCityLabel,
                primaryLocation: location,
                avgScore18: avgScore18,
                experienceYears: experienceYears,
                playsPerMonth: playsPerMonth,
                skillLevel: skillLevel,
                ageDecade: ageDecade
            )
            
            try await profileRepository.upsertPublicProfile(publicProfile)
            
            // Build and save private profile
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
    
    private func calculateAge(from date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: date, to: Date())
        return components.year ?? 0
    }
    
    private func ageDecadeFromAge(_ age: Int) -> AgeDecade {
        switch age {
        case ..<20: return .teens
        case 20..<30: return .twenties
        case 30..<40: return .thirties
        case 40..<50: return .forties
        case 50..<60: return .fifties
        case 60..<70: return .sixties
        default: return .seventiesPlus
        }
    }
    
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

