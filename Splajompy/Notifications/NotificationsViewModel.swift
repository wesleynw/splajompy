import SwiftUI

enum NotificationState {
  case idle
  case loading
  case loaded([NotificationDateSection: [Notification]], [Notification])
  case failed(Error)
}

enum NotificationFilter: String, CaseIterable, Identifiable {
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
    case .followers: return "Followers"
    case .poll: return "Polls"
    }
  }

  var apiValue: String? {
    self == .all ? nil : rawValue
  }
}

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var state: NotificationState = .idle
    @Published var hasMoreToLoad: Bool = true
    @Published var hasMoreUnreadToLoad: Bool = true
    @Published var selectedFilter: NotificationFilter = .all
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
        guard
          let date1 = sharedISO8601Formatter.date(
            from: notification1.createdAt
          ),
          let date2 = sharedISO8601Formatter.date(from: notification2.createdAt)
        else {
          return false
        }
        return date1 > date2
      }
    }

    private func updateLastTimestamp(
      from notifications: [Notification],
      isUnread: Bool
    ) {
      let sorted = sortNotificationsByDate(notifications)
      if let oldest = sorted.last {
        if isUnread {
          lastUnreadNotificationTime = oldest.createdAt
        } else {
          lastReadNotificationTime = oldest.createdAt
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
        beforeTime: ISO8601DateFormatter().string(from: Date()),
        limit: limit,
        notificationType: selectedFilter.apiValue
      )
      async let readResult =
        service.getReadNotificationWithSectionsWithTimeOffset(
          beforeTime: ISO8601DateFormatter().string(from: Date()),
          limit: limit,
          notificationType: selectedFilter.apiValue
        )

      let (unreadRes, readRes) = await (unreadResult, readResult)

      switch (unreadRes, readRes) {
      case (.success(let unreadNotifications), .success(let readSectionData)):
        state = .loaded(readSectionData.sections, unreadNotifications)

        updateLoadingState(newCount: unreadNotifications.count, isUnread: true)
        updateLoadingState(
          newCount: readSectionData.sections.values.flatMap { $0 }.count,
          isUnread: false
        )

        let allReadNotifications = readSectionData.sections.values.flatMap {
          $0
        }
        updateLastTimestamp(from: allReadNotifications, isUnread: false)
        updateLastTimestamp(from: unreadNotifications, isUnread: true)
      case (.error(let error), _), (_, .error(let error)):
        state = .failed(error)
      }
    }

    func loadMoreUnreadNotifications() async {
      guard !isFetchingUnread else { return }
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
      case .success(let newUnreadNotifications):
        if case .loaded(let currentSections, let currentUnreadNotifications) =
          state
        {
          let existingIds = Set(
            currentUnreadNotifications.map { $0.notificationId }
          )
          let uniqueNewNotifications = newUnreadNotifications.filter {
            !existingIds.contains($0.notificationId)
          }

          let mergedUnreadNotifications =
            currentUnreadNotifications + uniqueNewNotifications

          state = .loaded(currentSections, mergedUnreadNotifications)

          updateLoadingState(
            newCount: uniqueNewNotifications.count,
            isUnread: true
          )

          if !uniqueNewNotifications.isEmpty {
            updateLastTimestamp(from: uniqueNewNotifications, isUnread: true)
          }
        }
      case .error(let error):
        state = .failed(error)
      }
    }

    func loadMoreNotifications() async {
      guard !isFetching else { return }
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
      case .success(let newSectionData):
        if case .loaded(let currentSections, let unreadNotifications) = state {
          var mergedSections = currentSections

          for (section, notifications) in newSectionData.sections {
            if let existingNotifications = mergedSections[section] {
              let existingIds = Set(
                existingNotifications.map { $0.notificationId }
              )
              let newUniqueNotifications = notifications.filter {
                !existingIds.contains($0.notificationId)
              }

              mergedSections[section] =
                existingNotifications + newUniqueNotifications
            } else {
              mergedSections[section] = notifications
            }
          }

          state = .loaded(mergedSections, unreadNotifications)

          let allNewNotifications = newSectionData.sections.values.flatMap {
            $0
          }
          updateLoadingState(
            newCount: allNewNotifications.count,
            isUnread: false
          )

          if !allNewNotifications.isEmpty {
            updateLastTimestamp(from: allNewNotifications, isUnread: false)
          }
        }
      case .error(let error):
        state = .failed(error)
      }
    }

    func markNotificationAsRead(notificationId: Int) async {
      guard case .loaded(let sections, let unreadNotifications) = state else {
        return
      }

      var updatedSections = sections
      var updatedUnreadNotifications = unreadNotifications

      if let unreadIndex = unreadNotifications.firstIndex(where: {
        $0.notificationId == notificationId
      }) {
        var movedNotification = updatedUnreadNotifications.remove(
          at: unreadIndex
        )
        movedNotification.viewed = true

        guard
          let date = sharedISO8601Formatter.date(
            from: movedNotification.createdAt
          )
        else { return }
        let section = date.notificationSection()

        if var existingNotifications = updatedSections[section] {
          if !existingNotifications.contains(where: {
            $0.notificationId == movedNotification.notificationId
          }) {
            existingNotifications.append(movedNotification)
            updatedSections[section] = sortNotificationsByDate(
              existingNotifications
            )
          }
        } else {
          updatedSections[section] = [movedNotification]
        }
      }

      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          state = .loaded(updatedSections, updatedUnreadNotifications)
        }
      }

      let _ = await service.markNotificationAsRead(
        notificationId: notificationId
      )
    }

    func markAllNotificationsAsRead() {
      guard case .loaded(let sections, let unreadNotifications) = state else {
        return
      }

      var updatedSections = sections

      for (section, notifications) in sections {
        let updatedNotifications = notifications.map { notification in
          var updated = notification
          updated.viewed = true
          return updated
        }
        updatedSections[section] = updatedNotifications
      }

      for var unreadNotification in unreadNotifications {
        unreadNotification.viewed = true

        guard
          let date = sharedISO8601Formatter.date(
            from: unreadNotification.createdAt
          )
        else { continue }
        let section = date.notificationSection()

        if var existingNotifications = updatedSections[section] {
          if !existingNotifications.contains(where: {
            $0.notificationId == unreadNotification.notificationId
          }) {
            existingNotifications.append(unreadNotification)
            updatedSections[section] = sortNotificationsByDate(
              existingNotifications
            )
          }
        } else {
          updatedSections[section] = [unreadNotification]
        }
      }

      Task {
        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.3)) {
            state = .loaded(updatedSections, [])
          }
        }

        let _ = await service.markAllNotificationsAsRead()
      }

      lastUnreadNotificationTime = nil
      hasMoreUnreadToLoad = false
    }

    func setFilter(_ filter: NotificationFilter) {
      guard filter != selectedFilter else { return }

      selectedFilter = filter

      // Reset pagination state
      lastReadNotificationTime = nil
      lastUnreadNotificationTime = nil
      hasMoreToLoad = true
      hasMoreUnreadToLoad = true

      // Refetch with new filter
      Task {
        await refreshNotifications()
      }
    }
  }
}
