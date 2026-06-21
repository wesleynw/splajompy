import SwiftUI

enum NotificationState {
  case idle
  case loading
  case loaded([Notification])
  case failed(Error)
}

enum NotificationFilter: String, CaseIterable, Identifiable, Codable {
  case all = "all"
  case like = "like"
  case comment = "comment"
  case mention = "mention"
  case announcement = "announcement"
  case followers = "followers"
  case poll = "poll"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .all: return "All"
    case .like: return "Likes"
    case .comment: return "Comments"
    case .mention: return "Mentions"
    case .announcement: return "Announcements"
    case .followers: return "Follows"
    case .poll: return "Polls"
    }
  }

  var apiValue: String? {
    self == .all ? nil : rawValue
  }
}

extension NotificationsView {
  @MainActor @Observable class ViewModel {
    var state: NotificationState = .idle
    var hasMoreToLoad: Bool = true
    var hasMoreUnreadToLoad: Bool = true
    var selectedFilter: NotificationFilter = .all {
      didSet {
        guard selectedFilter != oldValue else { return }
        state = .idle
        Task { await refreshNotifications() }
      }
    }
    private var isFetching: Bool = false

    private var lastReadNotificationTime: Date?
    private var lastUnreadNotificationTime: Date?
    private let limit = 30

    private let service: NotificationServiceProtocol

    init(
      notificationService: NotificationServiceProtocol = NotificationService()
    ) {
      self.service = notificationService
    }

    func refreshNotifications() async {
      // if state != idle, there are existing notifications, leave them there while more are being fetched
      if case .idle = state {
        state = .loading
      }

      lastReadNotificationTime = nil
      lastUnreadNotificationTime = nil

      async let unreadResult = service.getUnreadNotificationsWithTimeOffset(
        beforeTime: nil,
        limit: limit,
        notificationType: selectedFilter.apiValue
      )
      async let readResult =
        service.getReadNotificationWithSectionsWithTimeOffset(
          beforeTime: nil,
          limit: limit,
          notificationType: selectedFilter.apiValue
        )

      let (unreadRes, readRes) = await (unreadResult, readResult)

      switch (unreadRes, readRes) {
      case (.success(let unreadNotifications), .success(let readNotifications)):
        state = .loaded(unreadNotifications + readNotifications)
        lastUnreadNotificationTime = unreadNotifications.last?.createdAt
        lastReadNotificationTime = readNotifications.last?.createdAt
        hasMoreUnreadToLoad = unreadNotifications.count == limit
        hasMoreToLoad = readNotifications.count == limit
      case (.failure(let error), _), (_, .failure(let error)):
        state = .failed(error)
      }
    }

    func loadMoreNotifications() async {
      guard !isFetching else { return }
      guard case .loaded(let notifications) = state else {
        return
      }

      isFetching = true
      defer { isFetching = false }

      let beforeTime =
        hasMoreUnreadToLoad
        ? lastUnreadNotificationTime : lastReadNotificationTime

      let result =
        hasMoreUnreadToLoad
        ? await service.getUnreadNotificationsWithTimeOffset(
          beforeTime: beforeTime?.ISO8601Format(),
          limit: limit,
          notificationType: selectedFilter.apiValue
        )
        : await service.getReadNotificationWithSectionsWithTimeOffset(
          beforeTime: beforeTime?.ISO8601Format(),
          limit: limit,
          notificationType: selectedFilter.apiValue
        )

      switch result {
      case .success(let newNotifications):
        if hasMoreUnreadToLoad {
          hasMoreUnreadToLoad = newNotifications.count == limit
          if let last = newNotifications.last {
            lastUnreadNotificationTime = last.createdAt
          }
        } else {
          hasMoreToLoad = newNotifications.count == limit
          if let last = newNotifications.last {
            lastReadNotificationTime = last.createdAt
          }
        }
        
        // we could have local notifications moved to the read section that are duplicated in the response here
        let filteredNew = newNotifications.filter { item in
          !notifications.contains { $0.notificationId == item.notificationId }
        }
        print("current have \(notifications.count)")
        print("adding \(filteredNew.count) notifications")
        state = .loaded(notifications + filteredNew)
      case .failure(let error):
        state = .failed(error)
      }
    }

    func markNotificationAsRead(notificationId: Int) async {
      guard case .loaded(var notifications) = state else { return }

      if let index = notifications.firstIndex(where: { $0.id == notificationId }
      ) {
        notifications[index].viewed = true
      }

      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          state = .loaded(notifications)
        }
      }

      let _ = await service.markNotificationAsRead(
        notificationId: notificationId
      )
    }

    func markAllNotificationsAsRead() {
      guard case .loaded(let notifications) = state else {
        return
      }

      // leave ui state
      //      for index in notifications.indices {
      //        notifications[index].viewed = true
      //      }

      Task {
        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.3)) {
            state = .loaded(notifications)
          }
        }

        let _ = await service.markAllNotificationsAsRead()
      }

      lastUnreadNotificationTime = nil
      hasMoreUnreadToLoad = false
    }

  }
}
