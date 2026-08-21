import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct TeePalsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

    init() {
        FirebaseApp.configure()
        TPImagePipeline.configure()

        #if DEBUG
        verifyCustomFonts()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.authService)
                .environmentObject(container)
                .environmentObject(deepLinkCoordinator)
                .onAppear {
                    appDelegate.deepLinkCoordinator = deepLinkCoordinator
                }
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .universalLinkReceived)) { notification in
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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Set by TeePalsApp.onAppear so push taps route directly through the coordinator
    /// without relying on NSNotification (which has race conditions on cold launch).
    var deepLinkCoordinator: DeepLinkCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Universal Link

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        print("App opened with Universal Link: \(url)")

        NotificationCenter.default.post(
            name: .universalLinkReceived,
            object: nil,
            userInfo: ["url": url]
        )

        return true
    }

    // MARK: - APNs Token → Firebase Messaging

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner + badge + sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    /// User tapped a notification — route to the correct screen.
    /// Uses the completion-handler variant (not async) so it fires synchronously
    /// on the main thread during app launch — avoids race with SwiftUI lifecycle.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Push notification tapped. Payload: \(userInfo)")

        if let coordinator = deepLinkCoordinator {
            coordinator.handlePushNotificationTap(userInfo: userInfo)
        } else {
            AppDelegate.coldLaunchPushPayload = userInfo
        }

        completionHandler()
    }

    /// Stored for cold-launch case when AppDelegate fires before SwiftUI view setup.
    static var coldLaunchPushPayload: [AnyHashable: Any]?
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let universalLinkReceived = NSNotification.Name("universalLinkReceived")
}
