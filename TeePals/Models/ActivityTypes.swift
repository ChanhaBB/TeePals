import Foundation

// MARK: - Activity Tab (Chip Selection)

/// The three chips in the Activity tab.
enum ActivityTab: String, CaseIterable, Identifiable {
    case schedule
    case invites
    case past

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .invites: return "Invites"
        case .past: return "Past"
        }
    }
}

// MARK: - Activity Round Item

/// Wrapper for rounds in the Activity view with computed properties for display.
struct ActivityRoundItem: Identifiable {
    let round: Round
    let role: ActivityRole
    let status: MemberStatus?
    let requestedAt: Date?
    let invitedAt: Date?
    let hostProfile: PublicProfile?
    let inviterName: String?
    let inviterPhotoURL: String?

    var id: String { round.id ?? UUID().uuidString }

    /// The badge to display on the card.
    var badge: RoundCardBadge {
        if role == .hosting { return .hosting }
        guard let status = status else { return .hosting }

        switch status {
        case .invited: return .invited
        case .requested: return .requested
        case .accepted: return round.isPast ? .played : .confirmed
        case .declined, .removed, .left: return .declined
        }
    }

    var needsAction: Bool { status == .invited }
    var isFuture: Bool { !round.isPast }
    var isPending: Bool { status == .requested }
    var isConfirmedOrHosting: Bool { role == .hosting || status == .accepted }
}

// MARK: - Activity Role

enum ActivityRole {
    case hosting
    case participating
}
