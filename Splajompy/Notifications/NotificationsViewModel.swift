import Foundation
import SwiftUI

@MainActor
class NotificationsViewModel: ObservableObject {
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

  func refreshNotifications() async {
    guard !isRefreshing else { return }

    isRefreshing = true

    if unreadNotifications.isEmpty && readNotifications.isEmpty {
      isInitialLoading = true
    }

    unreadOffset = 0
    readOffset = 0

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
      let filteredRead = notifications.filter { $0.viewed }
      readNotifications.append(contentsOf: filteredRead)
      canLoadMoreRead = notifications.count >= readLimit
      readOffset += notifications.count
    case .error:
      canLoadMoreRead = false
    }

    isLoadingMoreRead = false
  }

  func markNotificationAsRead(notificationId: Int) async {
    guard !isRefreshing else { return }

    guard let index = unreadNotifications.firstIndex(where: { $0.notificationId == notificationId })
    else {
      return
    }

    var notification = unreadNotifications[index]
    notification.viewed = true

    unreadNotifications.remove(at: index)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.easeInOut(duration: 0.3)) {
        self.readNotifications.insert(notification, at: 0)
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
        var updatedNotifications = unreadCopy
        for i in 0..<updatedNotifications.count {
          updatedNotifications[i].viewed = true
        }
        self.readNotifications.insert(contentsOf: updatedNotifications, at: 0)
      }
    }

    let _ = await service.markAllNotificationsAsRead()
  }
}
