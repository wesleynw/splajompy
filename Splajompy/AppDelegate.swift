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
      let payload = DeviceTokenRequest(
        deviceId: deviceId,
        deviceToken: deviceToken.base64EncodedString()
      )
      print("new device token: \(deviceToken.base64EncodedString())")

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
