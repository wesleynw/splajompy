import SwiftUI

struct NotificationIcon {
  private static func iconName(for notificationType: String) -> String {
    switch notificationType {
    case "like":
      return "heart"
    case "comment":
      return "bubble.middle.bottom"
    case "announcement":
      return "megaphone"
    case "mention":
      return "at"
    default:
      return "bell"
    }
  }

  static func icon(for notificationType: String) -> some View {
    Image(systemName: iconName(for: notificationType))
  }

  static func defaultIcon() -> some View {
    Image(systemName: "bell.fill")
  }
}
