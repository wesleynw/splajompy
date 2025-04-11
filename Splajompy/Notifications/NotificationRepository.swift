import Foundation

struct Notification: Identifiable, Decodable {
  let notificationId: Int
  let userId: Int
  let postId: Int?
  let commentId: Int?
  let message: String
  let link: String?
  var viewed: Bool
  let createdAt: String
  var id: Int { notificationId }
}

protocol NotificationServiceProtocol: Sendable {
  func getAllNotifications(offset: Int, limit: Int) async -> APIResult<
    [Notification]
  >

  func markNotificationAsRead(notificationId: Int) async -> APIResult<EmptyResponse>

  func markAllNotificationsAsRead() async -> APIResult<EmptyResponse>

  func hasUnreadNotifications() async -> APIResult<Bool>
}

struct NotificationService: NotificationServiceProtocol {
  func getAllNotifications(offset: Int, limit: Int) async -> APIResult<
    [Notification]
  > {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]

    return await APIService.performRequest(
      endpoint: "notifications",
      queryItems: queryItems
    )
  }

  func markNotificationAsRead(notificationId: Int) async -> APIResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "notifications/\(notificationId)/markRead", method: "POST")
  }

  func markAllNotificationsAsRead() async -> APIResult<EmptyResponse> {
    await APIService.performRequest(endpoint: "notifications/markRead", method: "POST")
  }

  func hasUnreadNotifications() async -> APIResult<Bool> {
    return await APIService.performRequest(endpoint: "notifications/hasUnread")
  }
}
