import Foundation

@MainActor @Observable
class NotificationBadgeStore {
  static let shared = NotificationBadgeStore()

  var unreadCount: Int = 0

  private let service: NotificationServiceProtocol

  init(notificationService: NotificationServiceProtocol = NotificationService()) {
    self.service = notificationService
  }

  func refresh() async {
    let result = await service.getUnreadNotificationCount()
    if case .success(let count) = result {
      unreadCount = count
    }
  }

  func reset() {
    unreadCount = 0
  }
}
