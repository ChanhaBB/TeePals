import SwiftUI
import FirebaseCore

@main
struct TeePalsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var container = AppContainer()
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(container)
                .environmentObject(deepLinkCoordinator)
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.universalLinkReceived)) { notification in
                    if let url = notification.userInfo?["url"] as? URL {
                        handleUniversalLink(url)
                    }
                }
        }
    }

    // MARK: - Universal Link Handling

    private func handleUniversalLink(_ url: URL) {
        // Parse: https://teepals-cf67c.web.app/r/{roundId}
        // TODO: Update to "teepals.com" once custom domain is configured
        guard url.host == "teepals-cf67c.web.app",
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "r" else {
            print("Invalid Universal Link format: \(url)")
            return
        }

        let roundId = url.pathComponents[2]

        // Extract optional query params
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let inviterUid = components?.queryItems?.first(where: { $0.name == "inviter" })?.value

        print("Received Universal Link - roundId: \(roundId), inviter: \(inviterUid ?? "none")")

        // Store pending deep link for post-login routing
        deepLinkCoordinator.storePendingDeepLink(roundId: roundId, inviterUid: inviterUid)

        // TODO: Navigate to round if already authenticated
        // This requires integration with RootView navigation state
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // iOS calls this when app opens via Universal Link (cold start)
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        print("App opened with Universal Link: \(url)")

        // Post notification for SwiftUI to handle
        NotificationCenter.default.post(
            name: NSNotification.Name.universalLinkReceived,
            object: nil,
            userInfo: ["url": url]
        )

        return true
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let universalLinkReceived = NSNotification.Name("universalLinkReceived")
}
