import Foundation
import SwiftUI

enum NotificationState {
  case idle
  case loading
  case loaded(unread: [Notification], read: [Notification])
  case failed(Error)
}

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var state: NotificationState = .idle
    @Published var isLoadingMoreUnread: Bool = false
    @Published var isLoadingMoreRead: Bool = false
    @Published var canLoadMoreUnread: Bool = true
    @Published var canLoadMoreRead: Bool = true

    private var unreadOffset = 0
    private var readOffset = 0
    private let limit = 10
    private let readLimit = 20
    private let service = NotificationService()

    var isEmpty: Bool {
      if case .loaded(let unread, let read) = state {
        return unread.isEmpty && read.isEmpty
      }
      return true
    }

    var unreadNotifications: [Notification] {
      if case .loaded(let unread, _) = state {
        return unread
      }
      return []
    }

    var readNotifications: [Notification] {
      if case .loaded(_, let read) = state {
        return read
      }
      return []
    }

    func refreshNotifications() async {
      if case .idle = state {
        state = .loading
      } else if case .loaded(let unread, let read) = state, unread.isEmpty && read.isEmpty {
        state = .loading
      }

      unreadOffset = 0
      readOffset = 0

      // async let allows us to use parallel async ops
      async let unreadResult = service.getUnreadNotifications(offset: 0, limit: limit)
      async let readResult = service.getAllNotifications(offset: 0, limit: readLimit)

      let (unread, read) = await (unreadResult, readResult)

      switch (unread, read) {
      case (.success(let unreadNotifications), .success(let allNotifications)):
        let filteredRead = allNotifications.filter { $0.viewed }
        state = .loaded(unread: unreadNotifications, read: filteredRead)

        canLoadMoreUnread = unreadNotifications.count >= limit
        unreadOffset = unreadNotifications.count

        canLoadMoreRead = allNotifications.count >= readLimit
        readOffset = allNotifications.count

      case (.error(let error), _), (_, .error(let error)):
        state = .failed(error)
        canLoadMoreUnread = false
        canLoadMoreRead = false
      }
    }

    func loadMoreUnreadNotifications() async {
      guard canLoadMoreUnread && !isLoadingMoreUnread else { return }

      isLoadingMoreUnread = true

      let result = await service.getUnreadNotifications(
        offset: unreadOffset,
        limit: limit
      )

      switch result {
      case .success(let notifications):
        if case .loaded(let currentUnread, let currentRead) = state {
          state = .loaded(unread: currentUnread + notifications, read: currentRead)
        }
        canLoadMoreUnread = notifications.count >= limit
        unreadOffset += notifications.count
      case .error:
        canLoadMoreUnread = false
      }

      isLoadingMoreUnread = false
    }

    func loadMoreReadNotifications() async {
      guard canLoadMoreRead && !isLoadingMoreRead else { return }

      isLoadingMoreRead = true

      let result = await service.getAllNotifications(
        offset: readOffset,
        limit: readLimit
      )

      switch result {
      case .success(let notifications):
        var addedNewNotifications = false

        if case .loaded(let currentUnread, let currentRead) = state {
          let filteredRead = notifications.filter { newNotification in
            newNotification.viewed
              && !currentRead.contains { existingNotification in
                existingNotification.notificationId == newNotification.notificationId
              }
          }

          if !filteredRead.isEmpty {
            state = .loaded(unread: currentUnread, read: currentRead + filteredRead)
            addedNewNotifications = true
          }
        }

        readOffset += notifications.count
        canLoadMoreRead = notifications.count >= readLimit

        if !addedNewNotifications && notifications.count >= readLimit {
          await loadMoreReadNotifications()
          return
        }
      case .error:
        canLoadMoreRead = false
      }

      isLoadingMoreRead = false
    }

    func markNotificationAsRead(notificationId: Int) async {
      guard case .loaded(var unread, let read) = state else { return }

      guard let index = unread.firstIndex(where: { $0.notificationId == notificationId }) else {
        return
      }

      var notification = unread[index]
      notification.viewed = true
      unread.remove(at: index)

      // Update state immediately with animation to remove from unread
      withAnimation(.easeInOut(duration: 0.2)) {
        state = .loaded(unread: unread, read: read)
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation(.easeInOut(duration: 0.3)) {
          if case .loaded(let currentUnread, var currentRead) = self.state {
            if !currentRead.contains(where: { $0.notificationId == notification.notificationId }) {
              currentRead.insert(notification, at: 0)
              self.state = .loaded(unread: currentUnread, read: currentRead)
            }
          }
        }
      }

      let _ = await service.markNotificationAsRead(notificationId: notificationId)
    }

    func markAllNotificationsAsRead() async {
      guard case .loaded(let unread, let read) = state else { return }

      let unreadCopy = unread
      state = .loaded(unread: [], read: read)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation(.easeInOut(duration: 0.4)) {
          let updatedNotifications = unreadCopy.map { notification in
            var updated = notification
            updated.viewed = true
            return updated
          }

          if case .loaded(_, var currentRead) = self.state {
            let newReadNotifications = updatedNotifications.filter { updatedNotification in
              !currentRead.contains(where: {
                $0.notificationId == updatedNotification.notificationId
              })
            }
            currentRead.insert(contentsOf: newReadNotifications, at: 0)
            self.state = .loaded(unread: [], read: currentRead)
          }
        }
      }

      let _ = await service.markAllNotificationsAsRead()
    }

  }
}
