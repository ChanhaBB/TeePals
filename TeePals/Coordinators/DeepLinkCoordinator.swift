import Foundation
import SwiftUI

/// Coordinates deep link handling across the app.
/// Manages pending deep links for unauthenticated users (resume after login).
@MainActor
final class DeepLinkCoordinator: ObservableObject {

    // MARK: - State

    @Published var pendingDeepLink: PendingDeepLink?
    @Published var navigationTrigger: String? // RoundId to navigate to

    // MARK: - Methods

    /// Store a deep link to be handled after authentication.
    func storePendingDeepLink(roundId: String, inviterUid: String?) {
        pendingDeepLink = PendingDeepLink(roundId: roundId, inviterUid: inviterUid)
    }

    /// Clear the pending deep link after it's been handled.
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    /// Check if there's a pending deep link and return it.
    func consumePendingDeepLink() -> PendingDeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }

    /// Trigger navigation to a specific round (used by views to navigate)
    func triggerNavigation(to roundId: String) {
        navigationTrigger = roundId
    }

    /// Clear navigation trigger after handling
    func clearNavigationTrigger() {
        navigationTrigger = nil
    }
}

// MARK: - Pending Deep Link Model

struct PendingDeepLink: Equatable {
    let roundId: String
    let inviterUid: String?
}
