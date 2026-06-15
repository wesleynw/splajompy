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
    private var isFetchingUnread: Bool = false

    private var lastReadNotificationTime: String?
    private var lastUnreadNotificationTime: String?
    private let limit = 30

    private let service: NotificationServiceProtocol

    init(
      notificationService: NotificationServiceProtocol = NotificationService()
    ) {
      self.service = notificationService
    }

    private func sortNotificationsByDate(_ notifications: [Notification])
      -> [Notification]
    {
      return notifications.sorted { notification1, notification2 in
        return notification1.createdAt > notification2.createdAt
      }
    }

    private func updateLastTimestamp(
      from notifications: [Notification],
      isUnread: Bool
    ) {
      let sorted = sortNotificationsByDate(notifications)
      if let oldest = sorted.last {
        let timeString = ISO8601DateFormatter().string(from: oldest.createdAt)
        if isUnread {
          lastUnreadNotificationTime = timeString
        } else {
          lastReadNotificationTime = timeString
        }
      }
    }

    private func updateLoadingState(newCount: Int, isUnread: Bool) {
      let hasMore = newCount >= limit
      if isUnread {
        hasMoreUnreadToLoad = hasMore
      } else {
        hasMoreToLoad = hasMore
      }
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
      case (.success(let unreadNotifications), .success(let readSectionData)):
        state = .loaded(readSectionData + unreadNotifications)

        updateLoadingState(newCount: unreadNotifications.count, isUnread: true)
        updateLoadingState(
          newCount: readSectionData.compactMap { $0 }.count,  // TODO: do i need compact map here?
          isUnread: false
        )

        let allReadNotifications = readSectionData.compactMap {
          $0
        }
        updateLastTimestamp(from: allReadNotifications, isUnread: false)
        updateLastTimestamp(from: unreadNotifications, isUnread: true)
      case (.failure(let error), _), (_, .failure(let error)):
        state = .failed(error)
      }
    }

    func loadMoreUnreadNotifications() async {
      guard !isFetchingUnread else { return }
      guard case .loaded(let notifications) = state else { return }

      isFetchingUnread = true
      defer { isFetchingUnread = false }

      let beforeTime =
        lastUnreadNotificationTime
        ?? ISO8601DateFormatter().string(from: Date())

      let result = await service.getUnreadNotificationsWithTimeOffset(
        beforeTime: beforeTime,
        limit: limit,
        notificationType: selectedFilter.apiValue
      )

      switch result {
      case .success(let newUnread):
        let existingIds = Set(notifications.map { $0.notificationId })
        let unique = newUnread.filter {
          !existingIds.contains($0.notificationId)
        }
        state = .loaded(notifications + unique)
        updateLoadingState(newCount: unique.count, isUnread: true)
        if !unique.isEmpty {
          updateLastTimestamp(from: unique, isUnread: true)
        }
      case .failure(let error):
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
        lastReadNotificationTime ?? ISO8601DateFormatter().string(from: Date())

      let result = await service.getReadNotificationWithSectionsWithTimeOffset(
        beforeTime: beforeTime,
        limit: limit,
        notificationType: selectedFilter.apiValue
      )

      switch result {
      case .success(let newRead):
        let existingIds = Set(notifications.map { $0.notificationId })
        let unique = newRead.filter { !existingIds.contains($0.notificationId) }
        state = .loaded(notifications + unique)
        updateLoadingState(newCount: unique.count, isUnread: false)
        if !unique.isEmpty {
          updateLastTimestamp(from: unique, isUnread: false)
        }
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
