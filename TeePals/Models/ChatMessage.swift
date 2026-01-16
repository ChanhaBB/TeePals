import Foundation

/// Chat message model for round-scoped group chat.
struct ChatMessage: Codable, Identifiable, Equatable {
    var id: String?
    let roundId: String
    let senderUid: String
    let text: String
    let type: MessageType
    let clientNonce: String  // For idempotency - prevents duplicate sends
    let createdAt: Date
    var photoUrl: String?  // Optional photo URL for photo messages
    
    // Denormalized sender info for display efficiency
    var senderNickname: String?
    var senderPhotoUrl: String?
    
    // Client-side state (not persisted)
    var sendState: MessageSendState = .sent
    
    init(
        id: String? = nil,
        roundId: String,
        senderUid: String,
        text: String,
        type: MessageType = .text,
        clientNonce: String = UUID().uuidString,
        createdAt: Date = Date(),
        photoUrl: String? = nil,
        senderNickname: String? = nil,
        senderPhotoUrl: String? = nil,
        sendState: MessageSendState = .sent
    ) {
        self.id = id
        self.roundId = roundId
        self.senderUid = senderUid
        self.text = text
        self.type = type
        self.clientNonce = clientNonce
        self.createdAt = createdAt
        self.photoUrl = photoUrl
        self.senderNickname = senderNickname
        self.senderPhotoUrl = senderPhotoUrl
        self.sendState = sendState
    }
    
    // MARK: - Equatable (exclude sendState for deduplication)
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        // Use clientNonce for idempotency comparison
        lhs.clientNonce == rhs.clientNonce
    }
    
    // MARK: - Display Helpers
    
    var isSystemMessage: Bool {
        type == .system
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

// MARK: - Message Type

enum MessageType: String, Codable {
    case text       // Regular user message
    case system     // System-generated (join, leave, etc.)
    
    var isSystem: Bool {
        self == .system
    }
}

// MARK: - Send State (Client-Side Only)

enum MessageSendState: String, Codable {
    case sending    // Optimistic - not yet confirmed
    case sent       // Confirmed by server
    case failed     // Failed to send
    
    var isSending: Bool {
        self == .sending
    }
    
    var isFailed: Bool {
        self == .failed
    }
}

// MARK: - System Message Templates

enum SystemMessageTemplate {
    case memberJoined(nickname: String)
    case memberLeft(nickname: String)
    case memberAccepted(nickname: String)
    case memberDeclined(nickname: String)
    case memberRemoved(nickname: String)
    case roundCanceled
    case teeTimeChanged
    case courseChanged
    
    var text: String {
        switch self {
        case .memberJoined(let nickname):
            return "\(nickname) joined the round"
        case .memberLeft(let nickname):
            return "\(nickname) left the round"
        case .memberAccepted(let nickname):
            return "\(nickname) was accepted to the round"
        case .memberDeclined(let nickname):
            return "\(nickname)'s request was declined"
        case .memberRemoved(let nickname):
            return "\(nickname) was removed from the round"
        case .roundCanceled:
            return "This round has been canceled"
        case .teeTimeChanged:
            return "Tee time has been updated"
        case .courseChanged:
            return "Course has been changed"
        }
    }
}

// MARK: - Pagination

struct ChatPageCursor {
    let lastMessageDate: Date
    let lastMessageId: String

    init(lastMessageDate: Date, lastMessageId: String) {
        self.lastMessageDate = lastMessageDate
        self.lastMessageId = lastMessageId
    }

    init?(from message: ChatMessage) {
        guard let id = message.id else { return nil }
        self.lastMessageDate = message.createdAt
        self.lastMessageId = id
    }
}

// MARK: - Chat Metadata

/// Per-user, per-round chat metadata for notification management.
/// Stored in rounds/{roundId}/chatMetadata/{userId}
struct ChatMetadata: Codable {
    let uid: String
    var lastReadAt: Date?
    var lastMessageAt: Date?
    var lastNotifiedAt: Date?
    var unreadCount: Int
    var isMuted: Bool

    init(uid: String) {
        self.uid = uid
        self.lastReadAt = nil
        self.lastMessageAt = nil
        self.lastNotifiedAt = nil
        self.unreadCount = 0
        self.isMuted = false
    }
}

