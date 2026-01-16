import Foundation

/// ViewModel for the Tier 1 onboarding wizard.
/// Manages draft state, validation, and atomic save at completion.
/// No data is saved to Firestore until ALL steps are complete.
@MainActor
final class Tier1OnboardingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?
    
    // MARK: - Navigation State
    
    @Published var currentStep: OnboardingStep = .nickname
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    
    // MARK: - Draft State (in-memory only until completion)
    
    @Published var nickname = ""
    @Published var birthDate: Date?
    @Published var primaryCityLabel = ""
    @Published var primaryLocation: GeoLocation?
    @Published var gender: Gender?
    
    // MARK: - Step Enum
    
    enum OnboardingStep: Int, CaseIterable {
        case nickname = 0
        case birthdate = 1
        case location = 2
        case gender = 3
        
        var title: String {
            switch self {
            case .nickname: return "What should we call you?"
            case .birthdate: return "When were you born?"
            case .location: return "Where do you play?"
            case .gender: return "How do you identify?"
            }
        }
        
        var subtitle: String {
            switch self {
            case .nickname: return "This is how other golfers will see you"
            case .birthdate: return "We use this to match you with compatible groups"
            case .location: return "We'll show you rounds nearby"
            case .gender: return "Helps with round preferences"
            }
        }
        
        var stepNumber: Int { rawValue + 1 }
        static var totalSteps: Int { allCases.count }
    }
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Validation
    
    var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespaces)
    }
    
    var isNicknameValid: Bool {
        let length = trimmedNickname.count
        return length >= 2 && length <= 20
    }
    
    var isBirthdateValid: Bool {
        guard let birthDate = birthDate else { return false }
        let age = calculateAge(from: birthDate)
        return age >= 18
    }
    
    var isLocationValid: Bool {
        !primaryCityLabel.isEmpty && primaryLocation != nil
    }
    
    var isGenderValid: Bool {
        gender != nil
    }
    
    var isCurrentStepValid: Bool {
        switch currentStep {
        case .nickname: return isNicknameValid
        case .birthdate: return isBirthdateValid
        case .location: return isLocationValid
        case .gender: return isGenderValid
        }
    }
    
    var canGoBack: Bool {
        currentStep.rawValue > 0
    }
    
    var isLastStep: Bool {
        currentStep == .gender
    }
    
    // MARK: - Navigation
    
    func goNext() async {
        guard isCurrentStepValid else { return }
        
        // Move to next step or save all and complete
        if isLastStep {
            await saveAllAndComplete()
        } else if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }
    
    func goBack() {
        guard canGoBack else { return }
        if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }
    
    // MARK: - Atomic Save (All at Once)
    
    /// Saves both public and private profiles atomically when onboarding is complete.
    private func saveAllAndComplete() async {
        guard let uid = currentUid() else {
            errorMessage = "Not signed in"
            return
        }
        
        guard let location = primaryLocation,
              let birthDate = birthDate,
              let gender = gender else {
            errorMessage = "Please complete all fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Save private profile first (birthDate)
            let privateProfile = PrivateProfile(
                id: uid,
                birthDate: formatBirthDate(birthDate)
            )
            try await profileRepository.upsertPrivateProfile(privateProfile)
            
            // Save public profile (this makes the user "authenticated")
            let publicProfile = PublicProfile(
                id: uid,
                nickname: trimmedNickname,
                gender: gender,
                primaryCityLabel: primaryCityLabel,
                primaryLocation: location,
                birthYear: extractBirthYear(from: birthDate)
            )
            try await profileRepository.upsertPublicProfile(publicProfile)
            
            // Mark as complete
            isComplete = true
            
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
        
        isLoading = false
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
    
    private func extractBirthYear(from date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }
    
    private func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
}

