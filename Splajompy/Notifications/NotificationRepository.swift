import Foundation

struct Notification: Identifiable, Decodable, Equatable {
  let notificationId: Int
  let userId: Int
  let postId: Int?
  let commentId: Int?
  let message: String
  let link: String?
  var viewed: Bool
  let createdAt: String
  let imageBlob: String?
  let imageWidth: Int32?
  let imageHeight: Int32?
  let facets: [Facet]?
  let notificationType: String

  var post: Post?
  var comment: Comment?

  var id: Int { notificationId }

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
  }
}

struct NotificationSectionData: Sendable, Decodable {
  let sections: [NotificationDateSection: [Notification]]
}

protocol NotificationServiceProtocol: Sendable {
  func getAllNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func getAllNotificationWithSections(offset: Int, limit: Int) async
    -> AsyncResult<NotificationSectionData>

  func getUnreadNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func getReadNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func getReadNotificationWithSections(offset: Int, limit: Int) async
    -> AsyncResult<NotificationSectionData>

  func markNotificationAsRead(notificationId: Int) async -> AsyncResult<
    EmptyResponse
  >

  func markAllNotificationsAsRead() async -> AsyncResult<EmptyResponse>

  func hasUnreadNotifications() async -> AsyncResult<Bool>

  func getUnreadNotificationCount() async -> AsyncResult<Int>

  func getReadNotificationsWithTimeOffset(beforeTime: String, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func getUnreadNotificationsWithTimeOffset(beforeTime: String, limit: Int) async -> AsyncResult<
    [Notification]
  >

  func getReadNotificationWithSectionsWithTimeOffset(beforeTime: String, limit: Int) async
    -> AsyncResult<NotificationSectionData>
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

  func markNotificationAsRead(notificationId: Int) async -> AsyncResult<
    EmptyResponse
  > {
    return await APIService.performRequest(
      endpoint: "notifications/\(notificationId)/markRead",
      method: "POST"
    )
  }

  func markAllNotificationsAsRead() async -> AsyncResult<EmptyResponse> {
    await APIService.performRequest(
      endpoint: "notifications/markRead",
      method: "POST"
    )
  }

  func hasUnreadNotifications() async -> AsyncResult<Bool> {
    return await APIService.performRequest(endpoint: "notifications/hasUnread")
  }

  func getUnreadNotificationCount() async -> AsyncResult<Int> {
    return await APIService.performRequest(
      endpoint: "notifications/unreadCount"
    )
  }

  func getAllNotificationWithSections(offset: Int, limit: Int) async
    -> AsyncResult<NotificationSectionData>
  {
    let result = await getAllNotifications(offset: offset, limit: limit)

    switch result {
    case .success(let notifications):
      let sectionedNotifications = Dictionary(grouping: notifications) {
        notification in
        guard
          let date = sharedISO8601Formatter.date(from: notification.createdAt)
        else {
          return NotificationDateSection.older
        }
        return date.notificationSection()
      }
      return .success(NotificationSectionData(sections: sectionedNotifications))
    case .error(let error):
      return .error(error)
    }
  }

  func getUnreadNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
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

  func getReadNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  > {
    let result = await getAllNotifications(offset: offset, limit: limit)

    switch result {
    case .success(let notifications):
      let readNotifications = notifications.filter { $0.viewed }
      return .success(readNotifications)
    case .error(let error):
      return .error(error)
    }
  }

  func getReadNotificationWithSections(offset: Int, limit: Int) async
    -> AsyncResult<NotificationSectionData>
  {
    let result = await getReadNotifications(offset: offset, limit: limit)

    switch result {
    case .success(let notifications):
      let sectionedNotifications = Dictionary(grouping: notifications) {
        notification in
        guard
          let date = sharedISO8601Formatter.date(from: notification.createdAt)
        else {
          return NotificationDateSection.older
        }
        return date.notificationSection()
      }
      return .success(NotificationSectionData(sections: sectionedNotifications))
    case .error(let error):
      return .error(error)
    }
  }

  func getReadNotificationsWithTimeOffset(beforeTime: String, limit: Int) async -> AsyncResult<
    [Notification]
  > {
    let queryItems = [
      URLQueryItem(name: "before_time", value: beforeTime),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]

    return await APIService.performRequest(
      endpoint: "notifications/read/time",
      queryItems: queryItems
    )
  }

  func getUnreadNotificationsWithTimeOffset(beforeTime: String, limit: Int) async -> AsyncResult<
    [Notification]
  > {
    let queryItems = [
      URLQueryItem(name: "before_time", value: beforeTime),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]

    return await APIService.performRequest(
      endpoint: "notifications/unread/time",
      queryItems: queryItems
    )
  }

  func getReadNotificationWithSectionsWithTimeOffset(beforeTime: String, limit: Int) async
    -> AsyncResult<NotificationSectionData>
  {
    let result = await getReadNotificationsWithTimeOffset(beforeTime: beforeTime, limit: limit)

    switch result {
    case .success(let notifications):
      let sectionedNotifications = Dictionary(grouping: notifications) {
        notification in
        guard
          let date = sharedISO8601Formatter.date(from: notification.createdAt)
        else {
          return NotificationDateSection.older
        }
        return date.notificationSection()
      }
      return .success(NotificationSectionData(sections: sectionedNotifications))
    case .error(let error):
      return .error(error)
    }
  }
}
