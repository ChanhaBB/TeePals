import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let displayName: String
    let createdAt: Date
    var lastActiveAt: Date
    
    init(id: String? = nil, displayName: String, createdAt: Date = Date(), lastActiveAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

