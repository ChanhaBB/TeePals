import Foundation

// MARK: - Activity Section

/// Sections in the unified Activity view.
enum ActivitySection: String, CaseIterable, Identifiable {
    case actionRequired
    case upcoming
    case pendingApproval  // Collapsed sub-section under Upcoming
    case past

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actionRequired: return "Action Required"
        case .upcoming: return "Upcoming"
        case .pendingApproval: return "Pending approval"
        case .past: return "Past"
        }
    }

    var icon: String {
        switch self {
        case .actionRequired: return "exclamationmark.circle.fill"
        case .upcoming: return "calendar"
        case .pendingApproval: return "hourglass"
        case .past: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Activity Filter

/// Filter options for Activity view.
enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case hosting
    case playing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .hosting: return "Hosting"
        case .playing: return "Playing"
        }
    }
}

// MARK: - Activity Round Item

/// Wrapper for rounds in the Activity view with computed badge and section.
struct ActivityRoundItem: Identifiable {
    let round: Round
    let role: ActivityRole
    let status: MemberStatus?  // nil for hosting rounds
    let requestedAt: Date?     // For sorting requested rounds
    let invitedAt: Date?       // For sorting invited rounds
    let hostProfile: PublicProfile?
    let inviterName: String?   // For invited rounds

    var id: String { round.id ?? UUID().uuidString }

    /// The badge to display on the card.
    var badge: RoundCardBadge {
        if role == .hosting {
            return .hosting
        }

        guard let status = status else { return .hosting }

        switch status {
        case .invited: return .invited
        case .requested: return .requested
        case .accepted:
            // Differentiate between upcoming (confirmed) and past (played)
            return round.isPast ? .played : .confirmed
        case .declined, .removed, .left:
            return .declined
        }
    }

    /// Whether this round needs action from the user.
    var needsAction: Bool {
        status == .invited
    }

    /// Whether this is a future round.
    var isFuture: Bool {
        !round.isPast
    }
}

// MARK: - Activity Role

/// User's role in a round for Activity view.
enum ActivityRole {
    case hosting
    case participating
}
