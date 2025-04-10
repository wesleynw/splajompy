import Foundation

struct Notification: Identifiable, Codable {
  let notificationId: Int
  let userId: Int
  let postId: Int
  let commentId: Int?
  let message: String
  let link: String?
  let viewed: Bool
  let createdAt: String
  var id: Int { notificationId }
}

struct NotificationService {
  static func getAllNotifications(offset: Int, limit: Int) async -> APIResult<
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
}
