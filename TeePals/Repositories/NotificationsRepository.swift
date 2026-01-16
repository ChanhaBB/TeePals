import Foundation

/// Repository protocol for notifications operations.
/// Abstracts Firestore implementation from ViewModels and Views.
protocol NotificationsRepository {

    // MARK: - Fetch (Pagination)

    /// Fetch recent notifications with pagination (no listener).
    /// - Parameters:
    ///   - limit: Max notifications to fetch
    ///   - after: Fetch notifications created after this date (for pagination)
    /// - Returns: Array of notifications sorted by createdAt descending
    func fetchNotifications(limit: Int, after: Date?) async throws -> [Notification]

    // MARK: - Mark as Read

    /// Mark a single notification as read.
    /// - Parameter notificationId: The notification ID to mark as read
    func markAsRead(notificationId: String) async throws

    /// Mark all notifications as read.
    func markAllAsRead() async throws

    // MARK: - Delete

    /// Delete a notification.
    /// - Parameter notificationId: The notification ID to delete
    func deleteNotification(notificationId: String) async throws

    // MARK: - Unread Count

    /// Get current unread count.
    /// - Returns: Number of unread notifications
    func getUnreadCount() async throws -> Int

    // MARK: - Real-time Listeners

    /// Listen to real-time notifications (top 20 only for performance).
    /// - Returns: AsyncStream emitting notification arrays
    func observeRecentNotifications() -> AsyncStream<[Notification]>

    /// Listen to unread count changes.
    /// - Returns: AsyncStream emitting unread counts
    func observeUnreadCount() -> AsyncStream<Int>
}

// MARK: - Notifications Errors

enum NotificationsError: LocalizedError {
    case notAuthenticated
    case targetNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to view notifications."
        case .targetNotFound:
            return "This item no longer exists."
        }
    }
}
