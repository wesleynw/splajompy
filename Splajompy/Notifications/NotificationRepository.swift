import Foundation

struct Notification: Identifiable, Decodable, Equatable {
  let notificationId: Int
  let userId: Int
  let postId: Int?
  let commentId: Int?
  let targetUserId: Int?
  let targetUserUsername: String?
  let message: String
  let link: String?
  var viewed: Bool
  let createdAt: Date
  let imageBlob: String?
  let imageWidth: Int?
  let imageHeight: Int?
  let facets: [Facet]?
  let notificationType: String
  var hasNotificationActors: Bool? = nil

  var post: Post?
  var comment: Comment?

  var id: Int { notificationId }

  var richContent: AttributedString {
    let markdown = generateAttributedStringUsingFacets(
      self.message,
      facets: facets ?? []
    )
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: markdown, options: options))
      ?? AttributedString(self.message)
  }

  static func == (lhs: Notification, rhs: Notification) -> Bool {
    return lhs.notificationId == rhs.notificationId
      && lhs.message == rhs.message
      && lhs.viewed == rhs.viewed
  }
}

protocol NotificationServiceProtocol: Sendable {
  func markNotificationAsRead(notificationId: Int) async -> Result<Void, Error>

  func markAllNotificationsAsRead() async -> Result<Void, Error>

  func hasUnreadNotifications() async -> Result<Bool, Error>

  func getUnreadNotificationCount() async -> Result<Int, Error>

  func getReadNotificationsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String?
  )
    async -> Result<[Notification], Error>

  func getUnreadNotificationsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String?
  ) async -> Result<
    [Notification], Error
  >

  func getReadNotificationWithSectionsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String?
  ) async
    -> Result<[Notification], Error>
}

struct NotificationService: NotificationServiceProtocol {
  func markNotificationAsRead(notificationId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "notifications/\(notificationId)/markRead",
      method: "POST"
    )
  }

  func markAllNotificationsAsRead() async -> Result<Void, Error> {
    await APIService.performRequest(
      endpoint: "notifications/markRead",
      method: "POST"
    )
  }

  func hasUnreadNotifications() async -> Result<Bool, Error> {
    return await APIService.performRequest(endpoint: "notifications/hasUnread")
  }

  func getUnreadNotificationCount() async -> Result<Int, Error> {
    return await APIService.performRequest(
      endpoint: "notifications/unreadCount"
    )
  }

  func getReadNotificationsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String? = nil
  ) async -> Result<
    [Notification], Error
  > {
    var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

    if let beforeTime {
      queryItems.append(URLQueryItem(name: "before_time", value: beforeTime))
    }

    if let notificationType = notificationType {
      queryItems.append(
        URLQueryItem(name: "notification_type", value: notificationType)
      )
    }

    return await APIService.performRequest(
      endpoint: "notifications/read/time",
      queryItems: queryItems
    )
  }

  func getUnreadNotificationsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String? = nil
  ) async -> Result<
    [Notification], Error
  > {
    var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

    if let beforeTime {
      queryItems.append(URLQueryItem(name: "before_time", value: beforeTime))
    }

    if let notificationType = notificationType {
      queryItems.append(
        URLQueryItem(name: "notification_type", value: notificationType)
      )
    }

    return await APIService.performRequest(
      endpoint: "notifications/unread/time",
      queryItems: queryItems
    )
  }

  func getReadNotificationWithSectionsWithTimeOffset(
    beforeTime: String?,
    limit: Int,
    notificationType: String? = nil
  ) async
    -> Result<[Notification], Error>
  {
    return await getReadNotificationsWithTimeOffset(
      beforeTime: beforeTime,
      limit: limit,
      notificationType: notificationType
    )
  }
}
