import Foundation

// MARK: - Protocol

/// Service for fetching user's round activity (hosting + requested).
protocol ActivityRoundsService {
    
    /// Fetch rounds the current user is hosting.
    /// - Parameter dateRange: Optional date filter
    /// - Returns: Array of rounds ordered by startTime
    func fetchHostingRounds(dateRange: DateRangeOption?) async throws -> [Round]
    
    /// Fetch rounds the current user has requested to join.
    /// - Parameter dateRange: Optional date filter
    /// - Returns: Array of RoundRequest items (round + status)
    func fetchRequestedRounds(dateRange: DateRangeOption?) async throws -> [RoundRequest]
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

