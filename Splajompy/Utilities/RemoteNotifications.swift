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
}
