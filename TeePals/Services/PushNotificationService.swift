import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit

/// Manages FCM token registration, permission requests, and token persistence.
///
/// Setup checklist (one-time, done in Xcode):
///   1. Signing & Capabilities → + → "Push Notifications"
///   2. SPM: add the FirebaseMessaging target to the existing firebase-ios-sdk package
///   3. Firebase Console → Project Settings → Cloud Messaging → upload APNs Auth Key (.p8)
///
/// After that, `requestPermissionAndRegister()` is called automatically once the user
/// reaches authState == .authenticated (wired in AppContainer).
final class PushNotificationService: NSObject {

    // MARK: - Dependencies

    private let userRepository: UserRepository
    private var currentUid: () -> String?

    // MARK: - Init

    init(userRepository: UserRepository, currentUid: @escaping () -> String?) {
        self.userRepository = userRepository
        self.currentUid = currentUid
        super.init()
        Messaging.messaging().delegate = self
    }

    // MARK: - Public API

    /// Requests UNUserNotification authorization and registers for remote notifications.
    /// Safe to call on every launch — iOS only shows the system prompt once.
    /// Silently re-registers on subsequent launches to keep the FCM token fresh.
    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()

        // Check current status before requesting to avoid unnecessary prompts
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            guard let granted = try? await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            ), granted else {
                print("Push notifications permission denied by user.")
                return
            }
        case .denied:
            print("Push notifications are disabled. User must enable in Settings.")
            return
        default:
            break // .authorized, .provisional, .ephemeral — proceed to register
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {

    /// Called by Firebase Messaging whenever a new or refreshed FCM token is available.
    /// Persists the token to `users/{uid}` so Cloud Functions can deliver push notifications.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, let uid = currentUid() else { return }
        Task {
            do {
                try await userRepository.updateFCMToken(token, uid: uid)
                print("FCM token saved for uid: \(uid)")
            } catch {
                print("Failed to save FCM token: \(error)")
            }
        }
    }
}
