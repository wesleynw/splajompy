import AppKit
import PostHog
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate,
  @MainActor UNUserNotificationCenterDelegate
{
  func applicationDidFinishLaunching(
    _ notification: UserNotifications.Notification
  ) {
    UNUserNotificationCenter.current().delegate = self

    if UserDefaults.standard.bool(forKey: "push_notifications_enabled") {
      Task { @MainActor in
        NSApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }
      .joined()

    RemoteNotificationUtilities.registerDeviceWithAPI(token: tokenString)
  }

  func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PostHogSDK.shared.capture(
      "notification-registration-failure",
      properties: ["error": error.localizedDescription]
    )
  }

  @MainActor
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
