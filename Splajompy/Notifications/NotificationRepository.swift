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
  let imageBlob: String?
  let imageWidth: Int32
  let imageHeight: Int32
  let facets: [Facet]?

  var post: Post?
  var comment: Comment?

  var id: Int { notificationId }
}

protocol NotificationServiceProtocol: Sendable {
  func getAllNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func markNotificationAsRead(notificationId: Int) async -> AsyncResult<EmptyResponse>

  func markAllNotificationsAsRead() async -> AsyncResult<EmptyResponse>

  func hasUnreadNotifications() async -> AsyncResult<Bool>

  func getUnreadNotificationCount() async -> AsyncResult<Int>
}

struct NotificationService: NotificationServiceProtocol {
  func getAllNotifications(offset: Int, limit: Int) async -> AsyncResult<
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

  func markNotificationAsRead(notificationId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "notifications/\(notificationId)/markRead", method: "POST")
  }

  func markAllNotificationsAsRead() async -> AsyncResult<EmptyResponse> {
    await APIService.performRequest(endpoint: "notifications/markRead", method: "POST")
  }

  func hasUnreadNotifications() async -> AsyncResult<Bool> {
    return await APIService.performRequest(endpoint: "notifications/hasUnread")
  }

  func getUnreadNotificationCount() async -> AsyncResult<Int> {
    return await APIService.performRequest(endpoint: "notifications/unreadCount")
  }
}
