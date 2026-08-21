import Foundation

/// Steps in the Create Round wizard flow.
enum CreateRoundStep: Int, CaseIterable {
    case course = 0
    case dateTime = 1
    case settings = 2
    case review = 3
    
    var title: String {
        switch self {
        case .course: return "Course"
        case .dateTime: return "Date & Time"
        case .settings: return "Settings"
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

    // MARK: - Edit Mode

    let isEditMode: Bool
    private let existingRound: Round?

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
    
    // MARK: - Step 3: Round Settings
    
    @Published var visibility: RoundVisibility = .public
    @Published var groupSize: Int = 4
    @Published var greenFee: String = ""
    
    // MARK: - Step 3 (continued): Host Message
    
    @Published var hostMessage = ""
    
    static let groupSizeRange = 2...8
    static let defaultHostMessage = "Join me for a round!"
    
    // Join policy is determined by visibility
    var joinPolicy: JoinPolicy {
        visibility.defaultJoinPolicy
    }
    
    // MARK: - Course Photo (loaded for review)
    
    @Published var coursePhotoURL: URL?
    
    // MARK: - Created Round
    
    @Published var createdRound: Round?
    
    // MARK: - Init

    /// Initialize for creating a new round
    init(
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
        self.isEditMode = false
        self.existingRound = nil

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

    /// Initialize for editing an existing round
    init(
        round: Round,
        roundsRepository: RoundsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundsRepository = roundsRepository
        self.currentUid = currentUid
        self.isEditMode = true
        self.existingRound = round

        // Initialize with existing round data
        self.selectedCourse = round.chosenCourse ?? round.courseCandidates.first

        // Use existing date/time or fall back to tomorrow at 8am
        let existingDateTime = round.chosenTeeTime ?? round.startTime
        if let existingDateTime = existingDateTime {
            self.preferredDate = existingDateTime
            self.preferredTime = existingDateTime
        } else {
            // Fallback to tomorrow at 8am
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.day! += 1
            components.hour = 8
            components.minute = 0
            let tomorrow8am = calendar.date(from: components) ?? Date()
            self.preferredDate = tomorrow8am
            self.preferredTime = tomorrow8am
        }

        self.visibility = round.visibility
        self.groupSize = round.maxPlayers
        self.greenFee = round.price?.amount.map { String($0) } ?? ""
        self.hostMessage = round.description ?? ""

        // Start at review step in edit mode
        self.currentStep = .review
    }
    
    // MARK: - Computed Properties
    
    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(CreateRoundStep.totalSteps)
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
    
    var isCurrentStepValid: Bool {
        switch currentStep {
        case .course: return isCourseValid
        case .dateTime: return isDateTimeValid
        case .settings: return true
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
    
    func goToStep(_ step: CreateRoundStep) {
        currentStep = step
    }
    
    // MARK: - Course Selection
    
    func selectCourse(_ course: CourseCandidate) {
        selectedCourse = course
        // Clear cached photo URL so it reloads when returning to review step
        coursePhotoURL = nil
    }

    func clearCourse() {
        selectedCourse = nil
        coursePhotoURL = nil
    }
    
    // MARK: - Course Photo
    
    func loadCoursePhoto(using service: CoursePhotoService?) async {
        guard let service, let course = selectedCourse, coursePhotoURL == nil else { return }
        coursePhotoURL = await service.fetchPhotoURL(for: course)
    }
    
    // MARK: - Build Round
    
    private func buildRound() -> Round? {
        guard let uid = currentUid(),
              let course = selectedCourse else { return nil }
        
        let feeAmount = Int(greenFee)
        let price: RoundPrice? = feeAmount != nil ? RoundPrice(type: .estimate, amount: feeAmount) : nil
        
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
            requirements: nil,
            price: price,
            priceTier: nil,
            description: hostMessage.isEmpty ? Self.defaultHostMessage : hostMessage,
            maxPlayers: groupSize
        )
    }
    
    // MARK: - Create/Update Round

    func createRound() async -> Bool {
        if isEditMode {
            return await updateRound()
        } else {
            return await createNewRound()
        }
    }

    private func createNewRound() async -> Bool {
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

    private func updateRound() async -> Bool {
        guard var updatedRound = existingRound,
              let course = selectedCourse else {
            errorMessage = "Unable to update round. Please try again."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            // Update round properties
            let feeAmount = Int(greenFee)
            let price: RoundPrice? = feeAmount != nil ? RoundPrice(type: .estimate, amount: feeAmount) : nil

            // Generate denormalized fields for efficient queries
            let cityKey = Round.generateCityKey(from: course.cityLabel)
            let startTime = combinedDateTime
            let courseLat = course.location.latitude
            let courseLng = course.location.longitude

            // Compute geo data with geohash for search
            let geo = RoundGeo(location: course.location)

            updatedRound.title = autoTitle
            updatedRound.visibility = visibility
            updatedRound.joinPolicy = visibility.defaultJoinPolicy
            updatedRound.cityKey = cityKey
            updatedRound.startTime = startTime
            updatedRound.geo = geo
            updatedRound.courseLat = courseLat
            updatedRound.courseLng = courseLng
            updatedRound.courseCandidates = [course]
            updatedRound.chosenCourse = course
            updatedRound.teeTimeCandidates = [combinedDateTime]
            updatedRound.chosenTeeTime = combinedDateTime
            updatedRound.price = price
            updatedRound.description = hostMessage.isEmpty ? Self.defaultHostMessage : hostMessage
            updatedRound.maxPlayers = groupSize

            try await roundsRepository.updateRound(updatedRound)
            createdRound = updatedRound
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
