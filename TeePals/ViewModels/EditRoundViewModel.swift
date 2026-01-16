import Foundation

/// ViewModel for editing a round.
@MainActor
final class EditRoundViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    let round: Round
    private let roundsRepository: RoundsRepository
    
    // MARK: - Course State
    
    @Published var selectedCourse: CourseCandidate?
    @Published var manualCourseName: String = ""
    @Published var manualCityLabel: String = ""
    @Published var isManualEntry: Bool = false
    
    // MARK: - Other State
    
    @Published var preferredDate: Date
    @Published var visibility: RoundVisibility
    @Published var priceAmount: String  // Dollar amount (empty = Price TBD)
    @Published var minAge: Double
    @Published var maxAge: Double
    @Published var selectedSkillLevels: Set<SkillLevel>
    @Published var hostMessage: String
    
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    // Join policy is auto-determined by visibility
    var joinPolicy: JoinPolicy {
        visibility.defaultJoinPolicy
    }
    
    // MARK: - Init
    
    init(round: Round, roundsRepository: RoundsRepository) {
        self.round = round
        self.roundsRepository = roundsRepository
        
        // Initialize course state
        if let course = round.chosenCourse ?? round.courseCandidates.first {
            self.selectedCourse = course
            self.manualCourseName = course.name
            self.manualCityLabel = course.cityLabel
        } else {
            self.manualCourseName = ""
            self.manualCityLabel = ""
        }
        self.isManualEntry = false
        
        // Initialize other state
        self.preferredDate = round.displayTeeTime ?? Date()
        self.visibility = round.visibility
        self.priceAmount = round.price?.amount != nil ? "\(round.price!.amount!)" : ""
        self.minAge = Double(round.requirements?.minAge ?? 18)
        self.maxAge = Double(round.requirements?.maxAge ?? 65)
        self.selectedSkillLevels = Set(round.requirements?.skillLevelsAllowed ?? [])
        self.hostMessage = round.description ?? ""
    }
    
    // MARK: - Course Selection
    
    func selectCourse(_ course: CourseCandidate) {
        selectedCourse = course
        manualCourseName = course.name
        manualCityLabel = course.cityLabel
        isManualEntry = false
    }
    
    func switchToManualEntry() {
        isManualEntry = true
        selectedCourse = nil
    }
    
    // MARK: - Validation
    
    var canSave: Bool {
        if isManualEntry {
            return !manualCourseName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedCourse != nil
        }
    }
    
    // MARK: - Save
    
    /// Saves the round and returns the updated Round if successful, nil otherwise.
    func saveRound() async -> Round? {
        isSaving = true
        errorMessage = nil
        
        // Build course
        let course: CourseCandidate
        if isManualEntry {
            course = CourseCandidate(
                name: manualCourseName.trimmingCharacters(in: .whitespaces),
                cityLabel: manualCityLabel.trimmingCharacters(in: .whitespaces),
                location: round.courseCandidates.first?.location ?? GeoLocation(latitude: 0, longitude: 0)
            )
        } else if let selected = selectedCourse {
            course = selected
        } else {
            errorMessage = "Please select a course"
            isSaving = false
            return nil
        }
        
        // Build requirements
        let requirements = RoundRequirements(
            minAge: Int(minAge),
            maxAge: Int(maxAge),
            skillLevelsAllowed: selectedSkillLevels.isEmpty ? nil : Array(selectedSkillLevels)
        )
        
        // Build price (simple: just the amount, or nil if not specified)
        let priceAmountInt = Int(priceAmount)
        let price: RoundPrice? = priceAmountInt != nil ? RoundPrice(type: .estimate, amount: priceAmountInt) : nil
        
        var updatedRound = round
        updatedRound.courseCandidates = [course]
        updatedRound.chosenCourse = course
        updatedRound.teeTimeCandidates = [preferredDate]
        updatedRound.chosenTeeTime = preferredDate
        updatedRound.visibility = visibility
        updatedRound.joinPolicy = visibility.defaultJoinPolicy  // Auto-set
        updatedRound.priceTier = nil  // No longer using price tiers
        updatedRound.price = price
        updatedRound.requirements = requirements
        updatedRound.description = hostMessage.isEmpty ? nil : hostMessage
        updatedRound.updatedAt = Date()
        
        // Update denormalized fields for efficient queries
        updatedRound.cityKey = Round.generateCityKey(from: course.cityLabel)
        updatedRound.startTime = preferredDate
        updatedRound.courseLat = course.location.latitude
        updatedRound.courseLng = course.location.longitude
        
        // Compute geo data with geohash for search
        updatedRound.geo = RoundGeo(location: course.location)
        
        do {
            try await roundsRepository.updateRound(updatedRound)
            isSaving = false
            return updatedRound
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
