import Foundation

/// ViewModel for notifications list with real-time updates and pagination.
@MainActor
final class NotificationsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let notificationsRepository: NotificationsRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var recentNotifications: [Notification] = []  // Top 20 from listener
    @Published var olderNotifications: [Notification] = []   // Loaded via pagination
    @Published var unreadCount: Int = 0                      // Total unread notifications (all types)
    @Published var isLoading = true // Start as true to show skeleton immediately
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreNotifications = true

    var allNotifications: [Notification] {
        recentNotifications + olderNotifications
    }

    var isEmpty: Bool {
        allNotifications.isEmpty && !isLoading
    }

    // Group notifications by date section
    var groupedNotifications: [(String, [Notification])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [Notification]] = [:]

        for notif in allNotifications {
            let section: String
            if calendar.isDateInToday(notif.createdAt) {
                section = "Today"
            } else if calendar.isDateInYesterday(notif.createdAt) {
                section = "Yesterday"
            } else if let daysDiff = calendar.dateComponents([.day], from: notif.createdAt, to: now).day, daysDiff < 7 {
                section = "This Week"
            } else if let daysDiff = calendar.dateComponents([.day], from: notif.createdAt, to: now).day, daysDiff < 30 {
                section = "This Month"
            } else {
                section = "Earlier"
            }

            groups[section, default: []].append(notif)
        }

        // Sort sections
        let sectionOrder = ["Today", "Yesterday", "This Week", "This Month", "Earlier"]
        return sectionOrder.compactMap { section in
            guard let notifs = groups[section] else { return nil }
            return (section, notifs.sorted { $0.createdAt > $1.createdAt })
        }
    }

    // MARK: - Init

    init(
        notificationsRepository: NotificationsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.notificationsRepository = notificationsRepository
        self.currentUid = currentUid
    }

    // MARK: - Listeners

    func startListening() {
        // Listen to recent 20 notifications
        Task { @MainActor in
            for await notifications in notificationsRepository.observeRecentNotifications() {
                self.recentNotifications = notifications
                // Set loading to false after first batch arrives
                if self.isLoading {
                    self.isLoading = false
                }
            }
        }

        // Listen to unread count (all notification types)
        Task { @MainActor in
            for await count in notificationsRepository.observeUnreadCount() {
                self.unreadCount = count
            }
        }
    }

    // MARK: - Load Older Notifications (Pagination)

    func loadOlderNotifications() async {
        guard !isLoadingMore, hasMoreNotifications else { return }

        isLoadingMore = true

        do {
            let lastDate = allNotifications.last?.createdAt
            let moreNotifications = try await notificationsRepository.fetchNotifications(
                limit: 20,
                after: lastDate
            )

            olderNotifications.append(contentsOf: moreNotifications)
            hasMoreNotifications = moreNotifications.count >= 20
        } catch {
            print("Failed to load older notifications: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Actions

    func markAsRead(_ notification: Notification) async {
        guard let id = notification.id, !notification.isRead else { return }

        do {
            try await notificationsRepository.markAsRead(notificationId: id)
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    func markAllAsRead() async {
        do {
            try await notificationsRepository.markAllAsRead()
        } catch {
            print("Failed to mark all as read: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteNotification(_ notification: Notification) async {
        guard let id = notification.id else { return }

        do {
            try await notificationsRepository.deleteNotification(notificationId: id)
        } catch {
            print("Failed to delete notification: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        // Real-time listener handles recent notifications automatically
        // Just reset pagination
        olderNotifications = []
        hasMoreNotifications = true
        await loadOlderNotifications()
    }
}
