import Foundation

@MainActor @Observable
class NotificationBadgeStore {
  static let shared = NotificationBadgeStore()

  private(set) var unreadCount: Int = 0

  private let service: NotificationServiceProtocol
  private var revision = 0

  init(notificationService: NotificationServiceProtocol = NotificationService()) {
    self.service = notificationService
  }

  func refresh() async {
    guard !Task.isCancelled else { return }
    revision += 1
    let requestRevision = revision
    let result = await service.getUnreadNotificationCount()
    guard !Task.isCancelled, requestRevision == revision else { return }
    if case .success(let count) = result {
      unreadCount = count
    }
  }

  func clear() {
    revision += 1
    unreadCount = 0
  }

  func decrement() {
    revision += 1
    unreadCount = max(0, unreadCount - 1)
  }
}
