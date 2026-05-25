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

    let payload = DeviceTokenRequest(
      deviceToken: tokenString
    )

    if let data = try? JSONEncoder().encode(payload) {
      Task {
        let _: AsyncResult<EmptyResponse> = await APIService.performRequest(
          endpoint: "notifications/registerDevice",
          method: "POST",
          queryItems: nil,
          body: data
        )
      }
    }
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
    guard
      let notificationType = response.notification.request.content.userInfo[
        "type"
      ] as? String
    else {
      print("unknown notification type")
      return
    }

    guard
      let identifier = response.notification.request.content.userInfo[
        "identifier"
      ] as? Int
    else {
      print("unknown notification type")
      return
    }

    let route: Route? =
      switch notificationType {
      case "follow":
        .profile(id: String(identifier), username: nil)
      case "comment", "mention":
        .post(id: identifier)
      default:
        nil
      }

    guard
      let notificationId = response.notification.request.content.userInfo[
        "notificationId"
      ] as? Int
    else {
      print("unknown notification id")
      return
    }

    Task {
      await NotificationService().markNotificationAsRead(
        notificationId: notificationId
      )
    }

    if let route {
      RoutingHelper.shared.pendingRoute = route
    }

    completionHandler()
  }
}
