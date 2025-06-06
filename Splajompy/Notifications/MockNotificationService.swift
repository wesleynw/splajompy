import Foundation

class MockNotificationService: @unchecked Sendable, NotificationServiceProtocol
{
  func getUnreadNotificationCount() async -> AsyncResult<Int> {
    return .success(0)
  }

  enum Behavior {
    case success([Notification])
    case failure(Error)
    case delayed([Notification], TimeInterval)
    case unreadNotifications(Bool)
    case markReadSuccess
    case markReadFailure(Error)
  }

  struct MockError: Error, LocalizedError {
    var errorDescription: String?

    init(_ description: String) {
      self.errorDescription = description
    }
  }

  var behavior: Behavior

  private(set) var callHistory: [(offset: Int, limit: Int)] = []
  private(set) var markedAsReadIds: [Int] = []
  private(set) var markedAllAsReadCalls: Int = 0
  private(set) var hasUnreadCalls: Int = 0

  init(behavior: Behavior? = nil) {
    let defaultNotifications = Self.createDefaultNotifications()
    self.behavior = behavior ?? .success(defaultNotifications)
  }

  static func createDefaultNotifications() -> [Notification] {
    let baseDate = Date()
    let imageUrl =
      "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com//posts/6/1055/2c741d27-325a-46dd-a721-d5a7594ba66a.jpeg"

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    return [
      Notification(
        notificationId: 1001,
        userId: 6,
        postId: 2001,
        commentId: nil,
        message: "@joel liked your post",
        link: "/post/2001",
        viewed: false,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-3600)),
        imageBlob:
          "https://www.acouplecooks.com/wp-content/uploads/2021/05/Latte-Art-070.jpg",
        facets: [
          Facet(type: "mention", userId: 25, indexStart: 0, indexEnd: 5)
        ],
        post: Post(
          postId: 2001,
          userId: 6,
          text: "just discovered this amazing coffee shop",
          createdAt: formatter.string(from: baseDate.addingTimeInterval(-7200)),
          facets: nil
        ),
        comment: nil
      ),

      Notification(
        notificationId: 1002,
        userId: 6,
        postId: 2002,
        commentId: 3001,
        message: "@realsophie commented on your post",
        link: "/post/2002",
        viewed: false,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-7200)),
        imageBlob: nil,
        facets: [
          Facet(type: "mention", userId: 120, indexStart: 0, indexEnd: 11)
        ],
        post: Post(
          postId: 2002,
          userId: 6,
          text: "beautiful sunset from my balcony tonight",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-14400)
          ),
          facets: nil
        ),
        comment: Comment(
          commentId: 3001,
          postId: 2002,
          userId: 120,
          text: "stunning colors! what time was this taken?",
          createdAt: formatter.string(from: baseDate.addingTimeInterval(-7200))
        )
      ),

      Notification(
        notificationId: 1003,
        userId: 6,
        postId: 2003,
        commentId: nil,
        message: "@wesley mentioned you in a post",
        link: "/post/2003",
        viewed: true,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-10800)),
        imageBlob: nil,
        facets: [
          Facet(type: "mention", userId: 6, indexStart: 0, indexEnd: 7)
        ],
        post: Post(
          postId: 2003,
          userId: 1,
          text: "@wesley you up rn?",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-10800)
          ),
          facets: [
            Facet(type: "mention", userId: 6, indexStart: 0, indexEnd: 7)
          ]
        ),
        comment: nil
      ),

      Notification(
        notificationId: 1004,
        userId: 6,
        postId: 2004,
        commentId: 3002,
        message: "@splazackly liked your comment",
        link: "/post/2004",
        viewed: true,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-14400)),
        imageBlob: imageUrl,
        facets: [
          Facet(type: "mention", userId: 103, indexStart: 0, indexEnd: 11)
        ],
        post: Post(
          postId: 2004,
          userId: 15,
          text: "weekend farmers market haul",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-18000)
          ),
          facets: nil
        ),
        comment: Comment(
          commentId: 3002,
          postId: 2004,
          userId: 6,
          text: "you're incredible 😛😛😛",
          createdAt: formatter.string(from: baseDate.addingTimeInterval(-16200))
        )
      ),

      Notification(
        notificationId: 1005,
        userId: 6,
        postId: 2001,
        commentId: nil,
        message: "@giuseppe liked your post",
        link: "/post/2001",
        viewed: true,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-18000)),
        imageBlob: imageUrl,
        facets: [
          Facet(type: "mention", userId: 112, indexStart: 0, indexEnd: 9)
        ],
        post: Post(
          postId: 2001,
          userId: 6,
          text: "just discovered this amazing coffee shop",
          createdAt: formatter.string(from: baseDate.addingTimeInterval(-7200)),
          facets: nil
        ),
        comment: nil
      ),

      Notification(
        notificationId: 1006,
        userId: 6,
        postId: 2005,
        commentId: 3003,
        message: "@elena replied to your comment",
        link: "/post/2005",
        viewed: false,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-21600)),
        imageBlob: nil,
        facets: [
          Facet(type: "mention", userId: 97, indexStart: 0, indexEnd: 6)
        ],
        post: Post(
          postId: 2005,
          userId: 30,
          text: "thoughts on the new season finale?",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-28800)
          ),
          facets: nil
        ),
        comment: Comment(
          commentId: 3003,
          postId: 2005,
          userId: 97,
          text: "completely agree! that plot twist was unexpected",
          createdAt: formatter.string(from: baseDate.addingTimeInterval(-21600))
        )
      ),

      Notification(
        notificationId: 1007,
        userId: 6,
        postId: nil,
        commentId: nil,
        message: "Welcome to the community! 🎉",
        link: "/welcome",
        viewed: true,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-86400)),
        imageBlob: nil,
        facets: nil,
        post: nil,
        comment: nil
      ),

      Notification(
        notificationId: 1008,
        userId: 6,
        postId: nil,
        commentId: nil,
        message: "@pari started following you",
        link: "/profile/113",
        viewed: true,
        createdAt: formatter.string(from: baseDate.addingTimeInterval(-43200)),
        imageBlob: nil,
        facets: [
          Facet(type: "mention", userId: 113, indexStart: 0, indexEnd: 5)
        ],
        post: nil,
        comment: nil
      ),
    ]
  }

  static func createSampleNotifications(count: Int, startingId: Int = 1)
    -> [Notification]
  {
    var notifications: [Notification] = []

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    for i in startingId..<(startingId + count) {
      let id = i
      let message =
        id == 1
        ? "{tag:1:wesley}Test notification #\(id)" : "Test notification #\(id)"
      let link = id % 2 == 0 ? "/posts/\(200 + id)" : nil
      let commentId = id % 3 == 0 ? 300 + id : nil
      let dateString = formatter.string(
        from: Date().addingTimeInterval(-Double(id * 3600))
      )

      let notification = Notification(
        notificationId: id,
        userId: 100 + id,
        postId: 200 + id,
        commentId: commentId,
        message: message,
        link: link,
        viewed: id % 4 == 0,
        createdAt: dateString,
        imageBlob: nil,
        facets: nil,
        post: nil,
        comment: nil
      )

      notifications.append(notification)
    }

    return notifications
  }

  func getAllNotifications(offset: Int, limit: Int) async -> AsyncResult<
    [Notification]
  > {
    callHistory.append((offset, limit))

    switch behavior {
    case .success(let notifications):
      return .success(Array(notifications.dropFirst(offset).prefix(limit)))

    case .failure(let error):
      return .error(error)

    case .delayed(let notifications, let delay):
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return .success(Array(notifications.dropFirst(offset).prefix(limit)))

    default:
      return .error(
        MockError("Unexpected behavior set for getAllNotifications")
      )
    }
  }

  func markNotificationAsRead(notificationId: Int) async -> AsyncResult<
    EmptyResponse
  > {
    markedAsReadIds.append(notificationId)

    switch behavior {
    case .markReadSuccess:
      return .success(EmptyResponse())

    case .markReadFailure(let error):
      return .error(error)

    case .delayed(_, let delay):
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return .success(EmptyResponse())

    default:
      return .success(EmptyResponse())
    }
  }

  func markAllNotificationsAsRead() async -> AsyncResult<EmptyResponse> {
    markedAllAsReadCalls += 1

    switch behavior {
    case .markReadSuccess:
      return .success(EmptyResponse())

    case .markReadFailure(let error):
      return .error(error)

    case .delayed(_, let delay):
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return .success(EmptyResponse())

    default:
      return .success(EmptyResponse())
    }
  }

  func hasUnreadNotifications() async -> AsyncResult<Bool> {
    hasUnreadCalls += 1

    switch behavior {
    case .unreadNotifications(let hasUnread):
      return .success(hasUnread)

    case .failure(let error):
      return .error(error)

    case .delayed(_, let delay):
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      return .success(false)

    default:
      return .success(false)
    }
  }

  func resetCallHistory() {
    callHistory = []
    markedAsReadIds = []
    markedAllAsReadCalls = 0
    hasUnreadCalls = 0
  }
}
