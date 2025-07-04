import Foundation
import SwiftUI

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var unreadNotifications: [Notification] = []
    @Published var readNotifications: [Notification] = []
    @Published var isLoadingMoreUnread: Bool = false
    @Published var isLoadingMoreRead: Bool = false
    @Published var canLoadMoreUnread: Bool = true
    @Published var canLoadMoreRead: Bool = true
    @Published var isInitialLoading: Bool = false
    @Published var isRefreshing: Bool = false

    private var unreadOffset = 0
    private var readOffset = 0
    private let limit = 10
    private let readLimit = 20
    private let service = NotificationService()
    private var seenNotificationIds = Set<Int>()

    var isEmpty: Bool {
      unreadNotifications.isEmpty && readNotifications.isEmpty
    }

    func refreshNotifications() async {
      guard !isRefreshing else { return }

      isRefreshing = true

      if unreadNotifications.isEmpty && readNotifications.isEmpty {
        isInitialLoading = true
      }

      unreadOffset = 0
      readOffset = 0
      seenNotificationIds.removeAll()

      async let unreadResult = service.getUnreadNotifications(offset: 0, limit: limit)
      async let readResult = service.getAllNotifications(offset: 0, limit: readLimit)

      let (unread, read) = await (unreadResult, readResult)

      switch unread {
      case .success(let notifications):
        unreadNotifications = notifications
        canLoadMoreUnread = notifications.count >= limit
        unreadOffset = notifications.count
      case .error:
        unreadNotifications = []
        canLoadMoreUnread = false
      }

      switch read {
      case .success(let notifications):
        let filteredRead = notifications.filter { $0.viewed }
        readNotifications = filteredRead

        // Track all notification IDs to prevent duplicates
        for notification in unreadNotifications {
          seenNotificationIds.insert(notification.notificationId)
        }
        for notification in filteredRead {
          seenNotificationIds.insert(notification.notificationId)
        }

        canLoadMoreRead = notifications.count >= readLimit
        readOffset = notifications.count
      case .error:
        readNotifications = []
        canLoadMoreRead = false
      }

      isInitialLoading = false
      isRefreshing = false
    }

    func loadMoreUnreadNotifications() async {
      guard canLoadMoreUnread && !isLoadingMoreUnread && !isRefreshing else { return }

      isLoadingMoreUnread = true

      let result = await service.getUnreadNotifications(
        offset: unreadOffset,
        limit: limit
      )

      switch result {
      case .success(let notifications):
        unreadNotifications.append(contentsOf: notifications)
        canLoadMoreUnread = notifications.count >= limit
        unreadOffset += notifications.count
      case .error:
        canLoadMoreUnread = false
      }

      isLoadingMoreUnread = false
    }

    func loadMoreReadNotifications() async {
      guard canLoadMoreRead && !isLoadingMoreRead && !isRefreshing else { return }

      isLoadingMoreRead = true

      let result = await service.getAllNotifications(
        offset: readOffset,
        limit: readLimit
      )

      switch result {
      case .success(let notifications):
        let filteredRead = notifications.filter {
          $0.viewed && !seenNotificationIds.contains($0.notificationId)
        }

        if !filteredRead.isEmpty {
          readNotifications.append(contentsOf: filteredRead)
          updateSeenNotificationIds()
        }

        readOffset += notifications.count
        canLoadMoreRead = notifications.count >= readLimit

        if filteredRead.isEmpty && notifications.count >= readLimit {
          await loadMoreReadNotifications()
          return
        }
      case .error:
        canLoadMoreRead = false
      }

      isLoadingMoreRead = false
    }

    func markNotificationAsRead(notificationId: Int) async {
      guard !isRefreshing else { return }

      guard
        let index = unreadNotifications.firstIndex(where: { $0.notificationId == notificationId })
      else {
        return
      }

      var notification = unreadNotifications[index]
      notification.viewed = true

      unreadNotifications.remove(at: index)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        withAnimation(.easeInOut(duration: 0.3)) {
          if !self.readNotifications.contains(where: {
            $0.notificationId == notification.notificationId
          }) {
            self.readNotifications.insert(notification, at: 0)
            self.updateSeenNotificationIds()
          }
        }
      }

      let _ = await service.markNotificationAsRead(notificationId: notificationId)
    }

    func markAllNotificationsAsRead() async {
      guard !isRefreshing else { return }

      let unreadCopy = unreadNotifications

      unreadNotifications.removeAll()

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation(.easeInOut(duration: 0.4)) {
          let updatedNotifications = unreadCopy.map { notification in
            var updated = notification
            updated.viewed = true
            return updated
          }

          let newReadNotifications = updatedNotifications.filter { updatedNotification in
            !self.readNotifications.contains(where: {
              $0.notificationId == updatedNotification.notificationId
            })
          }
          self.readNotifications.insert(contentsOf: newReadNotifications, at: 0)
          self.updateSeenNotificationIds()
        }
      }

      let _ = await service.markAllNotificationsAsRead()
    }

    private func updateSeenNotificationIds() {
      seenNotificationIds.removeAll()
      for notification in unreadNotifications {
        seenNotificationIds.insert(notification.notificationId)
      }
      for notification in readNotifications {
        seenNotificationIds.insert(notification.notificationId)
      }
    }
  }
}
