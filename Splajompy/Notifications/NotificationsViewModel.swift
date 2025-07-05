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
    @Published var isFetching: Bool = false

    private var offset = 0
    private let limit = 60

    private let service = NotificationService()

    /** `refreshNotifications` clears stored notifications in the ViewModel and submits a request to re-fetch more notifications. */
    func refreshNotifications() async {
      // if state != idle, there are existing notifications, leave them there while more are being fetched
      if case .idle = state {
        state = .loading
      }

      offset = 0

      let result = await service.getAllNotifications(offset: 0, limit: limit)

      switch result {
      case .success(let notifications):
        state = .loaded(notifications)
        offset = notifications.count
      case .error(let error):
        state = .failed(error)
      }
    }

    func loadMoreNotifications() async {
      guard !isFetching else { return }
      isFetching = true
      defer { isFetching = false }

      let result = await service.getAllNotifications(
        offset: offset,
        limit: limit
      )

      switch result {
      case .success(let newNotifications):
        if case .loaded(let currentNotifications) = state {
          state = .loaded(currentNotifications + newNotifications)
          offset += newNotifications.count
        }
      case .error(let error):
        state = .failed(error)
      }
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

      let _ = await service.markNotificationAsRead(
        notificationId: notificationId
      )
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
