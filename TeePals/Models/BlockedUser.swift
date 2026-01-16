import Foundation

/// Blocked user record.
struct BlockedUser: Codable, Identifiable {
    var id: String?
    let blockedAt: Date
    
    init(id: String? = nil, blockedAt: Date = Date()) {
        self.id = id
        self.blockedAt = blockedAt
    }
}

/// User report record.
struct Report: Codable, Identifiable {
    var id: String?
    let reporterUid: String
    let reportedUid: String
    let reason: String
    let context: String?
    let createdAt: Date
    
    init(
        id: String? = nil,
        reporterUid: String,
        reportedUid: String,
        reason: String,
        context: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reporterUid = reporterUid
        self.reportedUid = reportedUid
        self.reason = reason
        self.context = context
        self.createdAt = createdAt
    }
}
