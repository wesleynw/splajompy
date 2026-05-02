import PostHog
import UIKit

struct DeviceTokenRequest: Codable {
  let deviceId: String
  let deviceToken: String
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication
      .LaunchOptionsKey: Any]?
  ) -> Bool {
    if UserDefaults.standard.bool(forKey: "push_notifications_enabled") {
      UIApplication.shared.registerForRemoteNotifications()
    }
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("did register for push notifications")
    if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
      let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

      let payload = DeviceTokenRequest(
        deviceId: deviceId,
        deviceToken: tokenString
      )
      print("new device token: \(tokenString)")

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
}
