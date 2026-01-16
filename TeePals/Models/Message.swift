import Foundation

/// Chat message model for round chat.
struct Message: Codable, Identifiable {
    var id: String?
    let senderUid: String
    let text: String
    let createdAt: Date
    
    // Joined from public profile (not stored)
    var senderNickname: String?
    
    init(
        id: String? = nil,
        senderUid: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.senderUid = senderUid
        self.text = text
        self.createdAt = createdAt
    }
}
