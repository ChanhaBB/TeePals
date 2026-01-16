import Foundation

/// Notification for in-app notification center.
/// Created server-side by Cloud Functions, read by clients.
struct Notification: Codable, Identifiable {
    var id: String?
    let type: NotificationType
    let actorUid: String?
    let actorNickname: String?
    let actorPhotoUrl: String?
    let actorUids: [String]?
    let actorCount: Int?
    let targetId: String?
    let targetType: TargetType?
    let title: String
    let body: String
    let metadata: [String: String]?
    var isRead: Bool
    let createdAt: Date
    let updatedAt: Date?

    /// Time ago string (e.g., "5m", "2h", "3d")
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Whether this notification is aggregated (multiple actors)
    var isAggregated: Bool {
        (actorCount ?? 0) > 1
    }

    /// All actor UIDs (single or multiple)
    var displayActorUids: [String] {
        actorUids ?? (actorUid != nil ? [actorUid!] : [])
    }
}

/// Notification type enum
enum NotificationType: String, Codable {
    // Round activity
    case roundJoinRequest
    case roundJoinAccepted
    case roundJoinDeclined
    case roundInvitation
    case roundCancelled
    case roundUpdated
    case roundChatMessage

    // Social activity
    case userFollowed
    case postUpvoted
    case postCommented
    case commentReplied
    case commentMentioned

    // System
    case welcomeMessage
    case tier2Reminder
    case roundReminder
    case feedbackReminder
}

/// Target type for navigation
enum TargetType: String, Codable {
    case round
    case post
    case comment
    case profile
}
