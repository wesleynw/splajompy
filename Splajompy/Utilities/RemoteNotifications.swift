import SwiftUI

struct RemoteNotificationUtilities {
  @MainActor static func unregisterForRemoteNotifications() {
    #if os(iOS)
      UIApplication.shared.unregisterForRemoteNotifications()
    #else
      NSApplication.shared.unregisterForRemoteNotifications()
    #endif
  }
}
