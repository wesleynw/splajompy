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
    private var service: NotificationService

    init() {
      self.service = NotificationService()
    }

    func loadMoreNotifications() async {
      guard case .loaded = state, canLoadMore else { return }

      if case .loaded(let notifications) = state {
        offset = notifications.count
      }

      await loadNotifications(reset: false)
    }

    func loadNotifications(reset: Bool = false) async {
      if reset {
        offset = 0
        state = .idle
      }

      state = .loading

      let result = await NotificationService.getAllNotifications(
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
      case .failure(let error):
        state = .failed(error)
      }
    }

    func refresh() async {
      await loadNotifications(reset: true)
    }
  }
}
