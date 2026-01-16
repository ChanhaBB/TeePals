import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Firestore implementation of NotificationsRepository.
/// Handles reading notifications, marking as read, and real-time listeners.
final class FirestoreNotificationsRepository: NotificationsRepository {

    private let db = Firestore.firestore()

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Paginated Fetch (No Listener)

    func fetchNotifications(limit: Int, after: Date?) async throws -> [Notification] {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        var query: Query = db
            .collection("notifications").document(uid)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let after = after {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: after))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            var notif = try? doc.data(as: Notification.self)
            notif?.id = doc.documentID
            return notif
        }
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: String) async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        try await db
            .collection("notifications").document(uid)
            .collection("items").document(notificationId)
            .updateData(["isRead": true])
    }

    func markAllAsRead() async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        let unreadSnapshot = try await db
            .collection("notifications").document(uid)
            .collection("items")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in unreadSnapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Delete

    func deleteNotification(notificationId: String) async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        try await db
            .collection("notifications").document(uid)
            .collection("items").document(notificationId)
            .delete()
    }

    // MARK: - Unread Count

    func getUnreadCount() async throws -> Int {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        let snapshot = try await db
            .collection("notifications").document(uid)
            .collection("items")
            .whereField("isRead", isEqualTo: false)
            .count
            .getAggregation(source: .server)

        return Int(truncating: snapshot.count)
    }

    // MARK: - Real-Time Listeners

    func observeRecentNotifications() -> AsyncStream<[Notification]> {
        AsyncStream { continuation in
            guard let uid = currentUid else {
                continuation.yield([])
                continuation.finish()
                return
            }

            let listener = db
                .collection("notifications").document(uid)
                .collection("items")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error observing notifications: \(error)")
                        continuation.yield([])
                        return
                    }

                    guard let snapshot = snapshot else {
                        continuation.yield([])
                        return
                    }

                    let notifications = snapshot.documents.compactMap { doc -> Notification? in
                        var notif = try? doc.data(as: Notification.self)
                        notif?.id = doc.documentID
                        return notif
                    }

                    continuation.yield(notifications)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func observeUnreadCount() -> AsyncStream<Int> {
        AsyncStream { continuation in
            guard let uid = currentUid else {
                continuation.yield(0)
                continuation.finish()
                return
            }

            let listener = db
                .collection("notifications").document(uid)
                .collection("items")
                .whereField("isRead", isEqualTo: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error observing unread count: \(error)")
                        continuation.yield(0)
                        return
                    }

                    continuation.yield(snapshot?.documents.count ?? 0)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
