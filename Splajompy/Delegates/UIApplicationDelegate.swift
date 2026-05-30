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
    
    PostHogSDK.shared.capture(
      "push_notification_click",
      properties: ["type": notificationType]
    )

    let route: Route? =
      switch notificationType {
      case "followers":
        .profile(id: String(identifier), username: nil)
      case "comment", "mention":
        .post(id: identifier)
      default:
        nil
      }

    if let route {
      RoutingHelper.shared.pendingRoute = route
    }
  }
}
