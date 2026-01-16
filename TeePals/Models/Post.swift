import Foundation

/// Post model for the social feed.
/// Supports text, photos, and optional round linking.
struct Post: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    var id: String?
    let authorUid: String
    var text: String
    var photoUrls: [String]
    var linkedRoundId: String?
    var visibility: PostVisibility

    // Feed ranking fields
    var cityId: String?
    var courseId: String?
    var tags: [String]?
    var isDeleted: Bool

    var upvoteCount: Int
    var commentCount: Int
    var isEdited: Bool
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - Denormalized (for display, not stored)
    
    var authorNickname: String?
    var authorPhotoUrl: String?
    var linkedRound: Round?
    
    // Client-side state
    var hasUpvoted: Bool?
    
    // MARK: - Constants
    
    static let maxPhotos = 4
    static let maxTextLength = 2000
    
    // MARK: - Init
    
    init(
        id: String? = nil,
        authorUid: String,
        text: String,
        photoUrls: [String] = [],
        linkedRoundId: String? = nil,
        visibility: PostVisibility = .public,
        cityId: String? = nil,
        courseId: String? = nil,
        tags: [String]? = nil,
        isDeleted: Bool = false,
        upvoteCount: Int = 0,
        commentCount: Int = 0,
        isEdited: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorNickname: String? = nil,
        authorPhotoUrl: String? = nil,
        linkedRound: Round? = nil,
        hasUpvoted: Bool? = nil
    ) {
        self.id = id
        self.authorUid = authorUid
        self.text = text
        self.photoUrls = photoUrls
        self.linkedRoundId = linkedRoundId
        self.visibility = visibility
        self.cityId = cityId
        self.courseId = courseId
        self.tags = tags
        self.isDeleted = isDeleted
        self.upvoteCount = upvoteCount
        self.commentCount = commentCount
        self.isEdited = isEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorNickname = authorNickname
        self.authorPhotoUrl = authorPhotoUrl
        self.linkedRound = linkedRound
        self.hasUpvoted = hasUpvoted
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
    
    // MARK: - Computed
    
    var hasPhotos: Bool { !photoUrls.isEmpty }
    var hasLinkedRound: Bool { linkedRoundId != nil }
    
    /// Relative time string for display
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Full date string for detail view
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Post Visibility

enum PostVisibility: String, Codable, CaseIterable {
    case `public`
    case friends
    
    var displayText: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2.fill"
        }
    }
}

// MARK: - Post Upvote

struct PostUpvote: Codable, Identifiable {
    var id: String { uid }
    let uid: String
    let createdAt: Date
    
    init(uid: String, createdAt: Date = Date()) {
        self.uid = uid
        self.createdAt = createdAt
    }
}

// MARK: - Feed Filter

enum FeedFilter: String, CaseIterable {
    case all
    case friendsOnly
    
    var displayText: String {
        switch self {
        case .all: return "All"
        case .friendsOnly: return "Friends"
        }
    }
}





