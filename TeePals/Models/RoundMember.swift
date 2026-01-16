import Foundation

/// Round member model aligned with v2 design doc.
/// Replaces the old Participant model.
struct RoundMember: Codable, Identifiable {
    var id: String?
    let uid: String
    let role: MemberRole
    var status: MemberStatus
    let createdAt: Date
    var updatedAt: Date

    // Invitation tracking
    var invitedBy: String?  // UID of user who sent the invite

    // Joined from public profile (not stored in subcollection)
    var nickname: String?
    var photoUrl: String?
    
    init(
        id: String? = nil,
        uid: String,
        role: MemberRole,
        status: MemberStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        invitedBy: String? = nil
    ) {
        self.id = id
        self.uid = uid
        self.role = role
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.invitedBy = invitedBy
    }
}

// MARK: - Member Enums

enum MemberRole: String, Codable {
    case host
    case member
}

enum MemberStatus: String, Codable {
    case accepted
    case requested
    case invited
    case declined
    case removed
    case left
}

