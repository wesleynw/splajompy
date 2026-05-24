import OSLog
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
    let modelLogger = Logger.init(
      subsystem: "com.myapp.models",
      category: "myapp.debugging"
    )
    modelLogger.warning("BOOTING")
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
    let modelLogger = Logger.init(
      subsystem: "com.myapp.models",
      category: "myapp.debugging"
    )
    modelLogger.warning("REGISTERING")
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
    let modelLogger = Logger.init(
      subsystem: "com.myapp.models",
      category: "myapp.debugging"
    )
    modelLogger.warning("CAPTURING")

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
      "push-notification-click",
      properties: ["type": notificationType]
    )

    let route: Route? =
      switch notificationType {
      case "follow":
        .profile(id: String(identifier), username: "idk")
      case "comment", "mention":
        .post(id: identifier)
      default:
        nil
      }
    
    modelLogger.warning("Route: \(route!.description, privacy: .public)")
    
    modelLogger.warning("PREROUTING")
    if let route {
      modelLogger.warning("ROUTING")
      NotificationCenter.default.post(
        name: .navigateFromNotification,
        object: route
      )
    }
  }
}


