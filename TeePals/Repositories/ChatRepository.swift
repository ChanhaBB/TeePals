import Foundation
import Combine

/// Repository protocol for round chat operations.
/// Abstracts Firestore implementation from ViewModels and Views.
protocol ChatRepository {
    
    // MARK: - Real-time Subscription
    
    /// Subscribe to messages for a round. Returns a publisher that emits message arrays.
    /// - Parameter roundId: The round to subscribe to
    /// - Returns: Publisher emitting sorted message arrays (newest last)
    func subscribeToMessages(roundId: String) -> AnyPublisher<[ChatMessage], Error>
    
    // MARK: - Fetch (Pagination)
    
    /// Fetch older messages with pagination.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - limit: Max messages to fetch
    ///   - before: Cursor for pagination (fetch messages before this)
    /// - Returns: Array of messages (oldest first)
    func fetchMessages(
        roundId: String,
        limit: Int,
        before: ChatPageCursor?
    ) async throws -> [ChatMessage]
    
    // MARK: - Send
    
    /// Send a text message to a round.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - text: Message text
    ///   - clientNonce: Unique ID for idempotency
    ///   - photoUrl: Optional photo URL for photo messages
    /// - Returns: The sent message with server-assigned ID
    func sendMessage(
        roundId: String,
        text: String,
        clientNonce: String,
        photoUrl: String?
    ) async throws -> ChatMessage
    
    /// Send a system message to a round.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - template: System message template
    func sendSystemMessage(
        roundId: String,
        template: SystemMessageTemplate
    ) async throws
    
    // MARK: - Moderation (Future)

    /// Report a message for moderation.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - messageId: The message to report
    ///   - reason: Report reason
    func reportMessage(
        roundId: String,
        messageId: String,
        reason: String
    ) async throws

    // MARK: - Chat Metadata

    /// Fetch chat metadata for current user in a round.
    /// - Parameter roundId: The round ID
    /// - Returns: Chat metadata if exists, nil otherwise
    func fetchChatMetadata(roundId: String) async throws -> ChatMetadata?

    /// Mark chat as read (reset unread count, update lastReadAt).
    /// - Parameter roundId: The round ID
    func markChatAsRead(roundId: String) async throws

    /// Mute/unmute chat notifications for a round.
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - isMuted: Whether to mute the chat
    func setChatMuted(roundId: String, isMuted: Bool) async throws

    /// Get total unread count across all rounds.
    /// - Returns: Sum of unread messages across all rounds
    func getTotalChatUnreadCount() async throws -> Int

    /// Observe total unread count changes.
    /// - Returns: AsyncStream emitting unread counts
    func observeTotalChatUnreadCount() -> AsyncStream<Int>

    /// Clear all chat unread counts across all rounds (for fixing stale counts).
    func clearAllChatUnreadCounts() async throws
}

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case notAuthenticated
    case notAcceptedMember
    case roundNotFound
    case messageTooLong
    case rateLimited
    case duplicateMessage
    case sendFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use chat."
        case .notAcceptedMember:
            return "You must be an accepted member to send messages."
        case .roundNotFound:
            return "This round no longer exists."
        case .messageTooLong:
            return "Message is too long. Please keep it under 1000 characters."
        case .rateLimited:
            return "You're sending messages too quickly. Please wait a moment."
        case .duplicateMessage:
            return "This message was already sent."
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        }
    }
}

// MARK: - Constants

enum ChatConstants {
    static let maxMessageLength = 1000
    static let defaultPageSize = 50
    static let rateLimitIntervalSeconds: TimeInterval = 1.0  // Min time between sends
}

