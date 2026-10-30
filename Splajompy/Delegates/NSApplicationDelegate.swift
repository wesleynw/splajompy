import AppKit
import PostHog
import UserNotifications
import os

class AppDelegate: NSObject, NSApplicationDelegate,
  @MainActor UNUserNotificationCenterDelegate
{
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "push_notifications"
  )

  func applicationDidFinishLaunching(
    _ notification: UserNotifications.Notification
  ) {
    logger.info("Reached applicationDidFinishLaunching")
    UNUserNotificationCenter.current().delegate = self

    let isNotificationsEnabled = UserDefaults.standard.bool(
      forKey: "push_notifications_enabled"
    )
    logger.info(
      "applicationDidFinishLaunching: are push notifications configured as enabled? \(isNotificationsEnabled, privacy: .public)"
    )

    if isNotificationsEnabled {
      Task { @MainActor in
        NSApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    logger.info("didRegisterForRemoteNotificationsWithDeviceToken")
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }
      .joined()

    RemoteNotificationUtilities.registerDeviceWithAPI(token: tokenString)
  }

  func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    logger.error(
      "didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription, privacy: .public)"
    )
    PostHogSDK.shared.capture(
      "notification-registration-failure",
      properties: ["error": error.localizedDescription]
    )
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication)
    -> Bool
  {
    return true
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
