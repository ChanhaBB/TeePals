import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    let senderUserId: String
    let text: String
    let createdAt: Date
    
    // Joined from user data (not stored)
    var senderDisplayName: String?
    
    init(id: String? = nil, senderUserId: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.senderUserId = senderUserId
        self.text = text
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, senderUserId, text, createdAt
    }
}

