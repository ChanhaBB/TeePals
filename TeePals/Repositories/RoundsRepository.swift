import Foundation

/// Protocol for rounds data access.
/// Abstracts Firestore implementation from ViewModels and Views.
protocol RoundsRepository {
    
    // MARK: - Round CRUD
    
    /// Creates a new round and returns the created round with ID.
    func createRound(_ round: Round) async throws -> Round
    
    /// Fetches a single round by ID.
    func fetchRound(id: String) async throws -> Round?
    
    /// Fetches rounds with optional filters. Returns paginated results.
    func fetchRounds(
        filters: RoundFilters,
        limit: Int,
        lastRound: Round?
    ) async throws -> [Round]
    
    /// Updates an existing round (host only).
    func updateRound(_ round: Round) async throws
    
    /// Cancels a round (sets status to canceled).
    func cancelRound(id: String) async throws
    
    // MARK: - Membership
    
    /// Fetches all members of a round.
    func fetchMembers(roundId: String) async throws -> [RoundMember]
    
    /// Requests to join a round.
    func requestToJoin(roundId: String) async throws
    
    /// Joins a round instantly (for instant join policy).
    func joinRound(roundId: String) async throws
    
    /// Host accepts a join request.
    func acceptMember(roundId: String, memberUid: String) async throws
    
    /// Host declines a join request.
    func declineMember(roundId: String, memberUid: String) async throws
    
    /// Host removes a member from round.
    func removeMember(roundId: String, memberUid: String) async throws
    
    /// Member leaves a round voluntarily.
    func leaveRound(roundId: String) async throws
    
    /// Host invites a user to a round.
    func inviteMember(roundId: String, targetUid: String) async throws

    /// Fetches current user's membership status for a round.
    func fetchMembershipStatus(roundId: String) async throws -> RoundMember?

    // MARK: - Invitations

    /// Fetches rounds where current user has been invited.
    func fetchInvitedRounds() async throws -> [Round]

    /// Accept an invitation to join a round.
    func acceptInvite(roundId: String) async throws

    /// Decline an invitation (removes the invitation record).
    func declineInvite(roundId: String) async throws
}

// MARK: - Round Filters

struct RoundFilters {
    // Core filters (server-side pushdown)
    var cityKey: String?
    var status: RoundStatus?
    var visibility: RoundVisibility?
    var dateRange: DateRangeOption
    
    // Client-side filters
    var radiusMiles: Int
    var centerLocation: GeoLocation?
    var excludeFullRounds: Bool
    
    // Sort option
    var sortBy: RoundSortOption
    
    // Legacy/optional
    var hostUid: String?
    var skillLevels: [SkillLevel]?
    
    init(
        cityKey: String? = nil,
        status: RoundStatus? = .open,
        visibility: RoundVisibility? = nil,
        dateRange: DateRangeOption = .next30,
        radiusMiles: Int = RoundFilters.defaultRadiusMiles,
        centerLocation: GeoLocation? = nil,
        excludeFullRounds: Bool = true,
        sortBy: RoundSortOption = .date,
        hostUid: String? = nil,
        skillLevels: [SkillLevel]? = nil
    ) {
        self.cityKey = cityKey
        self.status = status
        self.visibility = visibility
        self.dateRange = dateRange
        self.radiusMiles = radiusMiles
        self.centerLocation = centerLocation
        self.excludeFullRounds = excludeFullRounds
        self.sortBy = sortBy
        self.hostUid = hostUid
        self.skillLevels = skillLevels
    }
    
    // MARK: - Defaults
    
    static let defaultRadiusMiles = 25  // Updated per GEOHASH_PLAN.md
    static let defaultDateRange: DateRangeOption = .next30
    
    static var defaults: RoundFilters {
        RoundFilters()
    }
    
    // MARK: - Computed Date Bounds
    
    var startTimeMin: Date {
        dateRange.startDate
    }
    
    var startTimeMax: Date {
        dateRange.endDate
    }
}

// MARK: - Date Range Options

enum DateRangeOption: Equatable {
    case today
    case thisWeekend
    case next7
    case next30
    case custom(start: Date, end: Date)
    
    var displayText: String {
        switch self {
        case .today: return "Today"
        case .thisWeekend: return "This Weekend"
        case .next7: return "Next 7 Days"
        case .next30: return "Next 30 Days"
        case .custom: return "Custom"
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch self {
        case .today:
            return startOfToday
        case .thisWeekend:
            // Find next Saturday (or today if it's weekend)
            let weekday = calendar.component(.weekday, from: now)
            if weekday == 7 { // Saturday
                return startOfToday
            } else if weekday == 1 { // Sunday
                return startOfToday
            } else {
                let daysUntilSaturday = 7 - weekday
                return calendar.date(byAdding: .day, value: daysUntilSaturday, to: startOfToday) ?? startOfToday
            }
        case .next7, .next30:
            return startOfToday
        case .custom(let start, _):
            return calendar.startOfDay(for: start)
        }
    }
    
    var endDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch self {
        case .today:
            return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        case .thisWeekend:
            // End of Sunday
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilMonday: Int
            if weekday == 1 { // Sunday
                daysUntilMonday = 1
            } else if weekday == 7 { // Saturday
                daysUntilMonday = 2
            } else {
                daysUntilMonday = 8 - weekday + 1
            }
            return calendar.date(byAdding: .day, value: daysUntilMonday, to: startOfToday) ?? startOfToday
        case .next7:
            return calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        case .next30:
            return calendar.date(byAdding: .day, value: 30, to: startOfToday) ?? startOfToday
        case .custom(_, let end):
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        }
    }
    
    static var allPresets: [DateRangeOption] {
        [.today, .thisWeekend, .next7, .next30]
    }
}

// MARK: - Sort Options

enum RoundSortOption: String, CaseIterable {
    case date       // Soonest tee time first
    case distance   // Nearest first
    case newest     // Most recently posted
    
    var displayText: String {
        switch self {
        case .date: return "Soonest"
        case .distance: return "Nearest"
        case .newest: return "Newest"
        }
    }
}

// MARK: - Radius Options

enum RadiusOption: Int, CaseIterable {
    case five = 5
    case ten = 10
    case twentyFive = 25
    case fifty = 50
    case hundred = 100
    case any = 0
    
    var displayText: String {
        switch self {
        case .any: return "Any"
        default: return "\(rawValue) mi"
        }
    }
    
    var miles: Int? {
        self == .any ? nil : rawValue
    }
}

