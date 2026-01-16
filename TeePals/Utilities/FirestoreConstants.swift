import Foundation

/// Firestore collection names aligned with v2 design doc.
/// Only includes collections currently in use. Add more as features are implemented.
enum FirestoreCollection {
    // Core user data
    static let users = "users"
    
    // Split profiles (v2)
    static let profilesPublic = "profiles_public"
    static let profilesPrivate = "profiles_private"
    
    // Social graph
    static let follows = "follows"
    static let following = "following"   // Subcollection: follows/{uid}/following/{targetUid}
    static let followers = "followers"   // Subcollection: follows/{uid}/followers/{sourceUid}
    
    // Rounds
    static let rounds = "rounds"
    static let members = "members"           // Subcollection: rounds/{roundId}/members/{uid}
    static let messages = "messages"         // Subcollection: rounds/{roundId}/messages/{messageId}
    static let chatMetadata = "chatMetadata" // Subcollection: rounds/{roundId}/chatMetadata/{uid}
    
    // Posts (Phase 4)
    static let posts = "posts"
    static let upvotes = "upvotes"       // Subcollection: posts/{postId}/upvotes/{uid}
    static let comments = "comments"     // Subcollection: posts/{postId}/comments/{commentId}
    
    // Blocks
    static let blocks = "blocks"
    static let blocked = "blocked"       // Subcollection: blocks/{uid}/blocked/{blockedUid}
    
    // Reports
    static let reports = "reports"
    
    // Notifications
    static let notifications = "notifications"
    static let items = "items"           // Subcollection: notifications/{uid}/items/{notifId}
}
