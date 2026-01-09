import Foundation
import FirebaseFirestore

struct Participant: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let role: ParticipantRole
    let joinedAt: Date
    
    // Joined from user data (not stored in subcollection)
    var displayName: String?
    
    init(id: String? = nil, userId: String, role: ParticipantRole, joinedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, userId, role, joinedAt
    }
}

enum ParticipantRole: String, Codable {
    case host
    case player
}

