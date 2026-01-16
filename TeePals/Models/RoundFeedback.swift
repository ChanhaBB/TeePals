import Foundation

// MARK: - Round Feedback (Per User Per Round)

/// Feedback submitted by a participant after a round completes.
/// Collection: rounds/{roundId}/feedback/{reviewerUid}
struct RoundFeedback: Codable, Identifiable {
    var id: String?              // reviewerUid
    let roundId: String
    let reviewerUid: String
    let roundSafetyOK: Bool      // "Yes/No" primary question
    let skillLevelsAccurate: Bool? // From "Yes" flow (optional)
    let submittedAt: Date

    init(
        id: String? = nil,
        roundId: String,
        reviewerUid: String,
        roundSafetyOK: Bool,
        skillLevelsAccurate: Bool? = nil,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.roundId = roundId
        self.reviewerUid = reviewerUid
        self.roundSafetyOK = roundSafetyOK
        self.skillLevelsAccurate = skillLevelsAccurate
        self.submittedAt = submittedAt
    }
}

// MARK: - Player Endorsement (Per Reviewer-Target Pair Per Round)

/// Endorsement of a player by another participant.
/// Collection: rounds/{roundId}/endorsements/{endorsementId}
struct PlayerEndorsement: Codable, Identifiable {
    var id: String?              // Auto-generated
    let roundId: String
    let reviewerUid: String
    let targetUid: String
    let wouldPlayAgain: Bool     // Only true if explicitly tapped
    let submittedAt: Date

    init(
        id: String? = nil,
        roundId: String,
        reviewerUid: String,
        targetUid: String,
        wouldPlayAgain: Bool,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.roundId = roundId
        self.reviewerUid = reviewerUid
        self.targetUid = targetUid
        self.wouldPlayAgain = wouldPlayAgain
        self.submittedAt = submittedAt
    }
}

// MARK: - Incident Flag (Only When Issue Reported)

/// Report of an issue with a specific participant.
/// Collection: rounds/{roundId}/incidents/{incidentId}
struct IncidentFlag: Codable, Identifiable {
    var id: String?              // Auto-generated
    let roundId: String
    let reviewerUid: String
    let targetUid: String
    let issueTypes: [IssueType]  // Can select multiple
    let comment: String?         // Optional, 200 char max
    let submittedAt: Date
    var reviewed: Bool           // For moderation workflow

    init(
        id: String? = nil,
        roundId: String,
        reviewerUid: String,
        targetUid: String,
        issueTypes: [IssueType],
        comment: String? = nil,
        submittedAt: Date = Date(),
        reviewed: Bool = false
    ) {
        self.id = id
        self.roundId = roundId
        self.reviewerUid = reviewerUid
        self.targetUid = targetUid
        self.issueTypes = issueTypes
        self.comment = comment
        self.submittedAt = submittedAt
        self.reviewed = reviewed
    }
}

// MARK: - Issue Type

enum IssueType: String, Codable, CaseIterable {
    case noShow = "no_show"
    case late = "late"
    case poorCommunication = "poor_communication"
    case disrespectful = "disrespectful"
    case skillMismatch = "skill_mismatch"
    case other = "other"

    var displayName: String {
        switch self {
        case .noShow: return "No-show"
        case .late: return "Late (15+ min)"
        case .poorCommunication: return "Poor communication"
        case .disrespectful: return "Disrespectful behavior"
        case .skillMismatch: return "Skill mismatch"
        case .other: return "Other"
        }
    }
}

// MARK: - Pending Feedback

/// Tracks rounds that need feedback from a user.
/// Collection: pendingFeedback/{uid}/items/{roundId}
struct PendingFeedback: Codable, Identifiable {
    var id: String?              // roundId
    let roundId: String
    let completedAt: Date
    let expiresAt: Date          // 7 days after completion
    let participantUids: [String] // Who to provide feedback about
    let courseName: String       // For notification
    var reminderSent: Bool       // Track 24h reminder

    init(
        id: String? = nil,
        roundId: String,
        completedAt: Date,
        expiresAt: Date,
        participantUids: [String],
        courseName: String,
        reminderSent: Bool = false
    ) {
        self.id = id
        self.roundId = roundId
        self.completedAt = completedAt
        self.expiresAt = expiresAt
        self.participantUids = participantUids
        self.courseName = courseName
        self.reminderSent = reminderSent
    }

    /// Time remaining until expiration
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }

    /// Display text for time remaining
    var timeLeftText: String {
        if daysRemaining <= 0 {
            return "Expiring soon"
        } else if daysRemaining == 1 {
            return "1 day left"
        } else {
            return "\(daysRemaining) days left"
        }
    }

    /// Whether this is urgent (expires within 1 day)
    var isUrgent: Bool {
        daysRemaining <= 1
    }
}

// MARK: - Trust Tier

enum TrustTier: String, Codable, CaseIterable {
    case rookie = "rookie"
    case member = "member"
    case trusted = "trusted"
    case verified = "verified"

    var displayName: String {
        switch self {
        case .rookie: return "🌱 Rookie"
        case .member: return "🥉 Member"
        case .trusted: return "🥈 Trusted Member"
        case .verified: return "🥇 Verified Member"
        }
    }

    var badge: String {
        switch self {
        case .rookie: return "🌱"
        case .member: return "🥉"
        case .trusted: return "🥈"
        case .verified: return "🥇"
        }
    }
}
