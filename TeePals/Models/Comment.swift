import Foundation

/// Comment model with support for one level of nesting.
/// - depth 0: Top-level comments on the post
/// - depth 1: Direct replies to a top-level comment
/// - depth 2+: Flat with @mention (stored at depth 1 under same parent)
struct Comment: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    var id: String?
    let postId: String
    let authorUid: String
    var text: String
    var parentCommentId: String?  // nil = top-level
    var replyToUid: String?       // for @mention in flat replies
    var replyToNickname: String?  // denormalized for display
    var depth: Int                // 0 = top-level, 1 = nested reply
    var isEdited: Bool
    var isDeleted: Bool?          // true if soft-deleted (preserves threading)
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Likes

    var likeCount: Int?           // Total likes on this comment
    var hasLiked: Bool?           // True if current user liked this comment

    // MARK: - Denormalized (for display)

    var authorNickname: String?
    var authorPhotoUrl: String?
    
    // MARK: - Nested replies (client-side only, not stored)
    
    var replies: [Comment]?
    
    // MARK: - Constants
    
    static let maxDepth = 1
    static let maxTextLength = 1000
    
    // MARK: - Init
    
    init(
        id: String? = nil,
        postId: String,
        authorUid: String,
        text: String,
        parentCommentId: String? = nil,
        replyToUid: String? = nil,
        replyToNickname: String? = nil,
        depth: Int = 0,
        isEdited: Bool = false,
        isDeleted: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likeCount: Int? = nil,
        hasLiked: Bool? = nil,
        authorNickname: String? = nil,
        authorPhotoUrl: String? = nil,
        replies: [Comment]? = nil
    ) {
        self.id = id
        self.postId = postId
        self.authorUid = authorUid
        self.text = text
        self.parentCommentId = parentCommentId
        self.replyToUid = replyToUid
        self.replyToNickname = replyToNickname
        self.depth = min(depth, Comment.maxDepth)
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likeCount = likeCount
        self.hasLiked = hasLiked
        self.authorNickname = authorNickname
        self.authorPhotoUrl = authorPhotoUrl
        self.replies = replies
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
    
    // MARK: - Computed
    
    var isTopLevel: Bool { parentCommentId == nil }
    var isReply: Bool { parentCommentId != nil }
    var hasMention: Bool { replyToUid != nil }
    var isSoftDeleted: Bool { isDeleted == true }
    
    /// Time ago string for display
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Display text with @mention prefix if applicable
    var displayText: String {
        if isSoftDeleted {
            return "[Comment deleted]"
        }
        if let nickname = replyToNickname, depth >= Comment.maxDepth {
            return "@\(nickname) \(text)"
        }
        return text
    }
}

// MARK: - Comment Tree Builder

extension Array where Element == Comment {
    
    /// Builds a nested comment tree from flat list.
    /// Top-level comments will have their replies populated.
    func buildCommentTree() -> [Comment] {
        let topLevel = filter { $0.isTopLevel }
        let replies = filter { $0.isReply }
        
        // Group replies by parent
        let repliesByParent = Dictionary(grouping: replies) { $0.parentCommentId ?? "" }
        
        // Attach replies to parents
        return topLevel.map { parent in
            var p = parent
            p.replies = repliesByParent[parent.id ?? ""]?.sorted { $0.createdAt < $1.createdAt }
            return p
        }.sorted { $0.createdAt < $1.createdAt }
    }
}





