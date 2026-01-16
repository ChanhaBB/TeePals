import Foundation

// MARK: - Protocol

/// Service for fetching rounds hosted by followed users.
protocol FollowingRoundsService {
    
    /// Fetch upcoming rounds hosted by users the current user follows.
    /// - Parameter dateRange: Date filter
    /// - Returns: Array of rounds ordered by startTime
    func fetchFollowingHostedRounds(dateRange: DateRangeOption) async throws -> [Round]
}

