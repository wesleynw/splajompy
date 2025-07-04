import SwiftUI

struct NotificationIcon {
  private static func iconName(for notificationType: NotificationType) -> String {
    switch notificationType {
    case .like:
      return "heart"
    case .comment:
      return "bubble.middle.bottom"
    case .announcement:
      return "megaphone"
    case .mention:
      return "at"
    }
  }

  static func icon(for notificationType: NotificationType) -> some View {
    Image(systemName: iconName(for: notificationType))
  }

  static func defaultIcon() -> some View {
    Image(systemName: "bell.fill")
  }
}
