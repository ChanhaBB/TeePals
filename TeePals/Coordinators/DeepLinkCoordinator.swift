import Foundation
import SwiftUI

/// Coordinates deep link handling across the app.
/// Manages pending deep links for unauthenticated users (resume after login).
@MainActor
final class DeepLinkCoordinator: ObservableObject {

    // MARK: - State

    /// Universal-link deep link (e.g. shared round URL). Consumed by MainTabView.
    @Published var pendingDeepLink: PendingDeepLink?
    @Published var navigationTrigger: String?
    @Published var activityTabTarget: ActivityTab?
    @Published var roundsSegmentTarget: RoundsSegment?
    /// Non-nil when a push/deep-link tap should switch to a specific tab index.
    @Published var pendingTabSwitch: Int?

    // MARK: - Universal Link Methods

    func storePendingDeepLink(roundId: String, inviterUid: String?) {
        pendingDeepLink = PendingDeepLink(roundId: roundId, inviterUid: inviterUid)
    }

    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    func consumePendingDeepLink() -> PendingDeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }

    // MARK: - Navigation Helpers

    func triggerNavigation(to roundId: String) {
        navigationTrigger = roundId
    }

    func clearNavigationTrigger() {
        navigationTrigger = nil
    }

    func navigateToActivityTab(_ tab: ActivityTab) {
        activityTabTarget = tab
    }

    func consumeActivityTabTarget() -> ActivityTab? {
        let target = activityTabTarget
        activityTabTarget = nil
        return target
    }

    func navigateToRoundsSegment(_ segment: RoundsSegment) {
        roundsSegmentTarget = segment
    }

    func consumeRoundsSegmentTarget() -> RoundsSegment? {
        let target = roundsSegmentTarget
        roundsSegmentTarget = nil
        return target
    }

    // MARK: - Push Notification Tap Routing

    /// All push notification taps simply switch to the Notifications tab.
    /// The notification stays unread until the user taps the row in NotificationsView,
    /// which calls markAsRead. This keeps routing logic in one place
    /// (NotificationsView.handleNotificationTap) and avoids presentation conflicts.
    func handlePushNotificationTap(userInfo: [AnyHashable: Any]) {
        pendingTabSwitch = 3
    }
}

// MARK: - Models

struct PendingDeepLink: Equatable {
    let roundId: String
    let inviterUid: String?
}
