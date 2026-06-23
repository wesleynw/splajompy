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

  // TODO: this is kind of a hack. in an ideal world we'd have an observable object for each notification
  var id: String { "\(notificationId) \(viewed)" }

  var richContent: AttributedString {
    let markdown = generateAttributedStringUsingFacets(
      self.message,
      facets: facets ?? []
    )
    return try! AttributedString(
      markdown: markdown,
      options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
      )
    )
  }

  static func == (lhs: Notification, rhs: Notification) -> Bool {
    return lhs.notificationId == rhs.notificationId
      && lhs.message == rhs.message
  }
}

protocol NotificationServiceProtocol: Sendable {
  func getAllNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
  >

  func getUnreadNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
  >

  func getReadNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
  >

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
  func getAllNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
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

  func getUnreadNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
  > {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]

    return await APIService.performRequest(
      endpoint: "notifications/unread",
      queryItems: queryItems
    )
  }

  func getReadNotifications(offset: Int, limit: Int) async -> Result<
    [Notification], Error
  > {
    let result = await getAllNotifications(offset: offset, limit: limit)

    switch result {
    case .success(let notifications):
      let readNotifications = notifications.filter { $0.viewed }
      return .success(readNotifications)
    case .failure(let error):
      return .failure(error)
    }
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
    let result = await getReadNotificationsWithTimeOffset(
      beforeTime: beforeTime,
      limit: limit,
      notificationType: notificationType
    )

    return result

    //    switch result {
    //    case .success(let notifications):
    //      return .success(notifications)
    // TODO: cleanup
    //      let sectionedNotifications = Dictionary(grouping: notifications) {
    //        notification in
    //        return notification.createdAt.notificationSection()
    //      }
    //      return .success(NotificationSectionData(sections: sectionedNotifications))
    //    case .failure(let error):
    //      return .failure(error)
    //    }
  }
}
