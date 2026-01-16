import Foundation

/// Steps in the simplified Create Round wizard flow.
enum CreateRoundStep: Int, CaseIterable {
    case course = 0      // Golf course search/selection
    case dateTime = 1    // Preferred date & time
    case details = 2     // Settings & optional description
    case review = 3      // Final review before posting
    
    var title: String {
        switch self {
        case .course: return "Course"
        case .dateTime: return "Date & Time"
        case .details: return "Details"
        case .review: return "Review"
        }
    }
    
    var stepNumber: Int { rawValue + 1 }
    static var totalSteps: Int { allCases.count }
}

/// ViewModel for the simplified Create Round wizard.
@MainActor
final class CreateRoundViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let roundsRepository: RoundsRepository
    private let currentUid: () -> String?
    
    // MARK: - Navigation State
    
    @Published var currentStep: CreateRoundStep = .course
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    // MARK: - Step 1: Course
    
    @Published var selectedCourse: CourseCandidate?
    @Published var courseSearchText = ""
    
    // MARK: - Step 2: Date & Time (single preferred)
    
    @Published var preferredDate: Date
    @Published var preferredTime: Date
    
    // MARK: - Step 3: Details
    
    @Published var visibility: RoundVisibility = .public
    @Published var priceAmount: String = ""  // Dollar amount (empty = Price TBD)
    @Published var minAge: Int = 18
    @Published var maxAge: Int = 65
    @Published var skillLevels: Set<SkillLevel> = Set(SkillLevel.allCases) // All selected by default
    @Published var hostMessage = ""  // Renamed from description
    
    // Max players is always 4
    let maxPlayers = 4
    
    // Join policy is determined by visibility
    var joinPolicy: JoinPolicy {
        visibility.defaultJoinPolicy
    }
    
    // MARK: - Created Round
    
    @Published var createdRound: Round?
    
    // MARK: - Init
    
    init(
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
        
        // Default to tomorrow at 8am
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 8
        components.minute = 0
        let tomorrow8am = calendar.date(from: components) ?? Date()
        
        self.preferredDate = tomorrow8am
        self.preferredTime = tomorrow8am
    }
    
    // MARK: - Computed Properties
    
    var progress: Double {
        Double(currentStep.rawValue) / Double(CreateRoundStep.totalSteps - 1)
    }
    
    var canGoBack: Bool {
        currentStep.rawValue > 0
    }
    
    var isLastStep: Bool {
        currentStep == .review
    }
    
    /// Auto-generated title from course name (just the course name, no prefix)
    var autoTitle: String {
        if let course = selectedCourse {
            return course.name
        }
        return "Golf Round"
    }
    
    /// Combined preferred date and time
    var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: preferredDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: preferredTime)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? preferredDate
    }
    
    // MARK: - Step Validation
    
    var isCourseValid: Bool {
        selectedCourse != nil
    }
    
    var isDateTimeValid: Bool {
        combinedDateTime > Date() // Must be in the future
    }
    
    var isDetailsValid: Bool {
        true // All optional
    }
    
    var isCurrentStepValid: Bool {
        switch currentStep {
        case .course: return isCourseValid
        case .dateTime: return isDateTimeValid
        case .details: return isDetailsValid
        case .review: return true
        }
    }
    
    // MARK: - Navigation
    
    func goNext() {
        guard isCurrentStepValid else { return }
        
        if let nextStep = CreateRoundStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }
    
    func goBack() {
        if let prevStep = CreateRoundStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }
    
    // MARK: - Course Selection
    
    func selectCourse(_ course: CourseCandidate) {
        selectedCourse = course
    }
    
    func clearCourse() {
        selectedCourse = nil
    }
    
    // MARK: - Build Round
    
    private func buildRound() -> Round? {
        guard let uid = currentUid(),
              let course = selectedCourse else { return nil }
        
        // Build requirements if any are restricted
        var requirements: RoundRequirements?
        let hasAgeRestriction = minAge > 18 || maxAge < 65
        let hasSkillRestriction = skillLevels.count < SkillLevel.allCases.count
        
        if hasAgeRestriction || hasSkillRestriction {
            requirements = RoundRequirements(
                minAge: minAge > 18 ? minAge : nil,
                maxAge: maxAge < 65 ? maxAge : nil,
                skillLevelsAllowed: hasSkillRestriction ? Array(skillLevels) : nil
            )
        }
        
        // Build price (simple: just the amount, or nil if not specified)
        let priceAmountInt = Int(priceAmount)
        let price: RoundPrice? = priceAmountInt != nil ? RoundPrice(type: .estimate, amount: priceAmountInt) : nil
        
        // Generate denormalized fields for efficient queries
        let cityKey = Round.generateCityKey(from: course.cityLabel)
        let startTime = combinedDateTime
        let courseLat = course.location.latitude
        let courseLng = course.location.longitude
        
        // Compute geo data with geohash for search
        let geo = RoundGeo(location: course.location)
        
        #if DEBUG
        print("🏌️ Creating round with geo: lat=\(geo.lat), lng=\(geo.lng), geohash=\(geo.geohash)")
        #endif
        
        return Round(
            hostUid: uid,
            title: autoTitle,
            visibility: visibility,
            joinPolicy: visibility.defaultJoinPolicy,  // Auto-set from visibility
            cityKey: cityKey,
            startTime: startTime,
            geo: geo,
            courseLat: courseLat,
            courseLng: courseLng,
            courseCandidates: [course],
            chosenCourse: course,
            teeTimeCandidates: [combinedDateTime],
            chosenTeeTime: combinedDateTime,
            requirements: requirements,
            price: price,
            priceTier: nil,
            description: hostMessage.isEmpty ? nil : hostMessage,
            maxPlayers: maxPlayers
        )
    }
    
    // MARK: - Create Round
    
    func createRound() async -> Bool {
        guard let round = buildRound() else {
            errorMessage = "Unable to create round. Please try again."
            return false
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            createdRound = try await roundsRepository.createRound(round)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
