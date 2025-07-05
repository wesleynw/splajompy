import Foundation
import SwiftUI

enum NotificationState: Equatable {
  case idle
  case loading
  case loaded([Notification])
  case failed(Error)

  static func == (lhs: NotificationState, rhs: NotificationState) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle), (.loading, .loading):
      return true
    case (.loaded(let lhsNotifications), .loaded(let rhsNotifications)):
      return lhsNotifications.count == rhsNotifications.count
    case (.failed, .failed):
      return true
    default:
      return false
    }
  }
}

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var state: NotificationState = .idle
    @Published var isLoadingMore: Bool = false
    @Published var canLoadMore: Bool = true

    private var offset = 0
    private let limit = 20
    private let service = NotificationService()

    var notifications: [Notification] {
      guard case .loaded(let notifications) = state else { return [] }
      return notifications
    }

    var unreadNotifications: [Notification] {
      notifications.filter { !$0.viewed }
    }

    var readNotificationsByDate: [(key: String, value: [Notification])] {
      let readNotifications = notifications.filter { $0.viewed }
      let grouped = Dictionary(grouping: readNotifications) { notification in
        let date = sharedISO8601Formatter.date(from: notification.createdAt) ?? Date()
        return date.notificationSection().rawValue
      }

      return NotificationDateSection.allCases.compactMap { section in
        guard let sectionNotifications = grouped[section.rawValue], !sectionNotifications.isEmpty
        else { return nil }
        return (key: section.rawValue, value: sectionNotifications)
      }
    }

    var isEmpty: Bool {
      notifications.isEmpty
    }

    func refreshNotifications() async {
      if case .idle = state {
        state = .loading
      }

      offset = 0
      canLoadMore = true

      let result = await service.getAllNotifications(offset: 0, limit: limit)

      switch result {
      case .success(let notifications):
        state = .loaded(notifications)
        offset = notifications.count
        canLoadMore = notifications.count >= limit
      case .error(let error):
        state = .failed(error)
        canLoadMore = false
      }
    }

    func loadMoreNotifications() async {
      guard canLoadMore && !isLoadingMore else { return }

      isLoadingMore = true

      let result = await service.getAllNotifications(offset: offset, limit: limit)

      switch result {
      case .success(let newNotifications):
        if case .loaded(let currentNotifications) = state {
          let filteredNew = newNotifications.filter { newNotification in
            !currentNotifications.contains { $0.notificationId == newNotification.notificationId }
          }
          withAnimation(.easeInOut(duration: 0.3)) {
            state = .loaded(currentNotifications + filteredNew)
          }
          offset += newNotifications.count
          canLoadMore = newNotifications.count >= limit
        }
      case .error:
        canLoadMore = false
      }

      isLoadingMore = false
    }

    func markNotificationAsRead(notificationId: Int) async {
      guard case .loaded(let notifications) = state else { return }

      let updatedNotifications = notifications.map { notification in
        if notification.notificationId == notificationId {
          var updated = notification
          updated.viewed = true
          return updated
        }
        return notification
      }

      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          state = .loaded(updatedNotifications)
        }
      }

      let _ = await service.markNotificationAsRead(notificationId: notificationId)
    }

    func markAllNotificationsAsRead() async {
      guard case .loaded(let notifications) = state else { return }

      let updatedNotifications = notifications.map { notification in
        var updated = notification
        updated.viewed = true
        return updated
      }

      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          state = .loaded(updatedNotifications)
        }
      }

      let _ = await service.markAllNotificationsAsRead()
    }
  }
}
