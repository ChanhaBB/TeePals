import Foundation

/// Repository protocol for user reporting and blocking.
protocol ReportRepository {
    /// Submit a report against a user.
    func submitReport(report: Report) async throws

    /// Block a user (writes to blocks/{currentUid}/blocked/{blockedUid}).
    func blockUser(blockedUid: String) async throws
}
