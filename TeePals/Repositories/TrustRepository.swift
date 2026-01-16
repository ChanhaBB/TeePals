import Foundation

/// Repository protocol for trust and feedback operations.
/// Abstracts Firestore implementation from ViewModels and Views.
protocol TrustRepository {

    // MARK: - Feedback Submission

    /// Submit round feedback (primary "Yes/No" question).
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - roundSafetyOK: Whether everyone showed up and behaved respectfully
    ///   - skillLevelsAccurate: Optional skill accuracy answer
    /// - Returns: The created feedback document
    func submitRoundFeedback(
        roundId: String,
        roundSafetyOK: Bool,
        skillLevelsAccurate: Bool?
    ) async throws -> RoundFeedback

    /// Submit player endorsements.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - endorsements: Array of (targetUid, wouldPlayAgain) pairs
    func submitEndorsements(
        roundId: String,
        endorsements: [(targetUid: String, wouldPlayAgain: Bool)]
    ) async throws

    /// Submit incident report for a user.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - targetUid: The user being reported
    ///   - issueTypes: Array of issue types
    ///   - comment: Optional private comment (max 200 chars)
    func submitIncidentReport(
        roundId: String,
        targetUid: String,
        issueTypes: [IssueType],
        comment: String?
    ) async throws

    // MARK: - Pending Feedback

    /// Fetch pending feedback items for current user.
    /// - Returns: Array of pending feedback items, sorted by expiration
    func fetchPendingFeedback() async throws -> [PendingFeedback]

    /// Check if user has already submitted feedback for a round.
    /// - Parameter roundId: The round ID
    /// - Returns: True if feedback already submitted
    func hasFeedbackBeenSubmitted(roundId: String) async throws -> Bool

    /// Fetch a specific pending feedback item.
    /// - Parameter roundId: The round ID
    /// - Returns: Pending feedback if exists, nil otherwise
    func fetchPendingFeedbackItem(roundId: String) async throws -> PendingFeedback?
}

// MARK: - Trust Errors

enum TrustError: LocalizedError {
    case notAuthenticated
    case notRoundParticipant
    case roundNotCompleted
    case feedbackAlreadySubmitted
    case invalidInput(String)
    case submissionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to submit feedback."
        case .notRoundParticipant:
            return "You must be a participant to submit feedback."
        case .roundNotCompleted:
            return "Feedback can only be submitted after the round is completed."
        case .feedbackAlreadySubmitted:
            return "You have already submitted feedback for this round."
        case .invalidInput(let message):
            return message
        case .submissionFailed(let error):
            return "Failed to submit feedback: \(error.localizedDescription)"
        }
    }
}
