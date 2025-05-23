import Foundation

enum NotificationState {
  case idle
  case loading
  case loaded([Notification])
  case failed(Error)
}

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var canLoadMore: Bool = true
    @Published var state: NotificationState = .idle
    private var offset = 0
    private let limit = 10
    private var service: NotificationServiceProtocol

    init(service: NotificationServiceProtocol = NotificationService()) {
      self.service = service
    }

    func loadNotifications(reset: Bool = false) async {
      if reset {
        if case .idle = state {
          state = .loading
        }
        offset = 0
      }

      let result = await service.getAllNotifications(
        offset: offset,
        limit: limit
      )

      switch result {
      case .success(let notifications):
        if case .loaded(let existingNotifications) = state, !reset {
          state = .loaded(existingNotifications + notifications)
        } else {
          state = .loaded(notifications)
        }
        canLoadMore = notifications.count >= limit
        offset += notifications.count
      case .error(let error):
        state = .failed(error)
      }
    }

    func markNotificationAsRead(for notification: Notification) {
      guard case .loaded(var notifications) = state else {
        return
      }

      if let index = notifications.firstIndex(where: {
        $0.notificationId == notification.notificationId
      }) {
        notifications[index].viewed = true

        state = .loaded(notifications)
      }

      Task {
        await service.markNotificationAsRead(notificationId: notification.notificationId)
      }
    }

    func markAllNotificationsAsRead() {
      guard case .loaded(var notifications) = state else {
        return
      }

      for i in 0..<notifications.count {
        notifications[i].viewed = true
      }

      state = .loaded(notifications)

      Task {
        await service.markAllNotificationsAsRead()
      }
    }

    func refresh() async {
      await loadNotifications(reset: true)
    }
  }
}
