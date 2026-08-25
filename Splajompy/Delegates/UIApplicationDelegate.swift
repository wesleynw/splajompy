import PostHog
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate,
  @MainActor UNUserNotificationCenterDelegate
{
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication
      .LaunchOptionsKey: Any]?
  ) -> Bool {
    if UserDefaults.standard.bool(forKey: "push_notifications_enabled") {
      UIApplication.shared.registerForRemoteNotifications()
    }
    UNUserNotificationCenter.current().delegate = self

    UserDefaults.standard.register(defaults: [
      "push_pref_comments": true,
      "push_pref_mentions": true,
      "push_pref_follows": true,
    ])

    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }
      .joined()
    RemoteNotificationUtilities.registerDeviceWithAPI(token: tokenString)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PostHogSDK.shared.capture(
      "notification-registration-failure",
      properties: ["error": error.localizedDescription]
    )
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler:
      @escaping () -> Void
  ) {
    defer { completionHandler() }

    if let route = routeUNNotificationRequest(response.notification.request) {
      RoutingHelper.shared.pendingRoute = route
    }
  }
}
