import Foundation
import FirebaseFirestore

struct BlockedUser: Codable, Identifiable {
    @DocumentID var id: String?
    let blockedAt: Date
    
    init(id: String? = nil, blockedAt: Date = Date()) {
        self.id = id
        self.blockedAt = blockedAt
    }
}

struct Report: Codable, Identifiable {
    @DocumentID var id: String?
    let reporterUserId: String
    let reportedUserId: String
    let reason: String
    let context: String?
    let createdAt: Date
    
    init(
        id: String? = nil,
        reporterUserId: String,
        reportedUserId: String,
        reason: String,
        context: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reporterUserId = reporterUserId
        self.reportedUserId = reportedUserId
        self.reason = reason
        self.context = context
        self.createdAt = createdAt
    }
}

