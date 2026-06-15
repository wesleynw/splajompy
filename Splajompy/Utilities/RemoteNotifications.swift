import SwiftUI

struct RemoteNotificationUtilities {
  @MainActor static func unregisterForRemoteNotifications() {
    #if os(iOS)
      UIApplication.shared.unregisterForRemoteNotifications()
    #else
      NSApplication.shared.unregisterForRemoteNotifications()
    #endif
  }

  @MainActor static func registerForRemoteNotifications() {
    #if os(iOS)
      UIApplication.shared.registerForRemoteNotifications()
    #else
      NSApplication.shared.registerForRemoteNotifications()
    #endif
  }

  static func registerDeviceWithAPI(token: String) {
    let payload = DeviceRegisterRequest(
      token: token,
      comments: UserDefaults.standard.bool(forKey: "push_pref_comments"),
      mentions: UserDefaults.standard.bool(forKey: "push_pref_mentions"),
      followers: UserDefaults.standard.bool(forKey: "push_pref_follows")
    )

    if let data = try? JSONEncoder().encode(payload) {
      Task {
        let _: Result<Void, Error> = await APIService.performRequest(
          endpoint: "notifications/registerDevice",
          method: "POST",
          queryItems: nil,
          body: data
        )
      }
    }
  }
}
