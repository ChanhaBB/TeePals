import Foundation

// MARK: - Protocol

/// Service for fetching user's round activity (hosting + requested).
protocol ActivityRoundsService {
    
    /// Fetch rounds the current user is hosting.
    /// - Parameters:
    ///   - dateRange: Optional date filter
    ///   - includeCompleted: When true, also returns rounds with status `completed` (for past rounds).
    /// - Returns: Array of rounds ordered by startTime
    func fetchHostingRounds(dateRange: DateRangeOption?, includeCompleted: Bool) async throws -> [Round]
    
    /// Fetch rounds the current user has requested to join.
    /// - Parameter dateRange: Optional date filter
    /// - Returns: Array of RoundRequest items (round + status)
    func fetchRequestedRounds(dateRange: DateRangeOption?) async throws -> [RoundRequest]

    /// Fetch accepted rounds for any user by their UID.
    /// Used for profile history: shows all rounds they participated in (hosted or joined).
    /// - Parameters:
    ///   - uid: The user whose round history to fetch
    ///   - dateRange: Optional date filter
    /// - Returns: Accepted round requests ordered by startTime
    func fetchParticipatedRounds(for uid: String, dateRange: DateRangeOption?) async throws -> [RoundRequest]

    /// Fetch the set of round IDs where the current viewer is an accepted member.
    /// Lightweight — reads only membership documents (no round document fetches).
    /// Used to build the viewer's membership set for O(1) per-round visibility checks.
    /// - Returns: Set of round IDs
    func fetchViewerMemberRoundIds() async throws -> Set<String>
}

extension ActivityRoundsService {
    func fetchHostingRounds(dateRange: DateRangeOption?) async throws -> [Round] {
        try await fetchHostingRounds(dateRange: dateRange, includeCompleted: false)
    }
}

// MARK: - Request Model

/// A round request with its status (for Activity tab).
struct RoundRequest: Identifiable {
    let round: Round
    let status: MemberStatus
    let requestedAt: Date
    
    var id: String { round.id ?? UUID().uuidString }
    
    /// Display text for the request status badge.
    var statusBadgeText: String {
        switch status {
        case .requested: return "REQUESTED"
        case .accepted: return "APPROVED"
        case .declined: return "DECLINED"
        case .invited: return "INVITED"
        case .removed: return "REMOVED"
        case .left: return "WITHDRAWN"
        }
    }
    
    /// Whether this is a pending request.
    var isPending: Bool {
        status == .requested
    }
}

