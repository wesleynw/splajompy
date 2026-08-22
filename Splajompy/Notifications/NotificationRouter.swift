import PostHog
import UserNotifications

func routeUNNotificationRequest(_ request: UNNotificationRequest) -> Route? {
  guard
    let notificationType = request.content.userInfo[
      "type"
    ] as? String,
    let identifier = request.content.userInfo[
      "identifier"
    ] as? Int,
    let notificationId = request.content.userInfo["notificationId"] as? Int
  else {
    print("unknown notification type")
    return nil
  }

  Task {
    await NotificationService().markNotificationAsRead(
      notificationId: notificationId
    )
  }

  PostHogSDK.shared.capture(
    "push_notification_click",
    properties: ["type": notificationType]
  )

  return
    switch notificationType
  {
  case "followers":
    if let username = request.content.userInfo[
      "username"
    ] as? String {
      .profile(id: String(identifier), username: username)
    } else {
      nil
    }
  case "comment", "mention":
    .post(id: identifier)
  default:
    nil
  }
}
