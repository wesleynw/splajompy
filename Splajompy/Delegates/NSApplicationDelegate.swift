import AppKit
import PostHog
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  private let notificationDelegate = NotificationDelegate()

  func applicationDidFinishLaunching(
    _ notification: UserNotifications.Notification
  ) {
    if UserDefaults.standard.bool(forKey: "push_notifications_enabled") {
      Task { @MainActor in
        NSApplication.shared.registerForRemoteNotifications()
      }
    }

    UNUserNotificationCenter.current().delegate = notificationDelegate
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
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
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
        .profile(id: String(identifier), username: "idk")
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
      await NotificationService().markNotificationAsRead(notificationId: notificationId)
    }

    if let route {
      NotificationCenter.default.post(
        name: .pushNotificationReceived,
        object: nil,
        userInfo: ["route": route]
      )
    }
  }
}

extension Foundation.Notification.Name {
  static let pushNotificationReceived = Foundation.Notification.Name(
    "pushNotificationReceived"
  )
}
