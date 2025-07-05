import Foundation

enum NotificationType: String, Decodable, CaseIterable {
  case none = "default"
  case like = "like"
  case comment = "comment"
  case announcement = "announcement"
  case mention = "mention"
}

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
  let notificationType: NotificationType

  var post: Post?
  var comment: Comment?

  var id: Int { notificationId }

  var richContent: AttributedString {
    if let facets = self.facets {
      let markdown = GenerateAttributedStringUsingFacets(
        self.message,
        facets: facets
      )
      return try! AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )
    } else {
      return AttributedString(self.message)
    }
  }

  var relativeDate: String {
    let decoder = ISO8601DateFormatter()
    decoder.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full

    let date = decoder.date(from: self.createdAt) ?? Date()
    return formatter.localizedString(for: date, relativeTo: Date())
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
    let result = await getAllNotifications(offset: 0, limit: limit)

    switch result {
    case .success(let notifications):
      let readNotifications = notifications.filter { $0.viewed }

      let paginatedRead = Array(
        readNotifications.dropFirst(offset).prefix(limit)
      )
      return .success(paginatedRead)
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
}
