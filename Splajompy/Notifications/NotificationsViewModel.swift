import SwiftUI

enum NotificationState {
  case idle
  case loading
  case loaded([NotificationDateSection: [Notification]], [Notification])
  case failed(Error)
}

extension NotificationsView {
  @MainActor class ViewModel: ObservableObject {
    @Published var state: NotificationState = .idle
    @Published var isFetching: Bool = false

    private var readOffset = 0
    private var unreadOffset = 0
    private let limit = 30

    private let service = NotificationService()

    /** `refreshNotifications` clears stored notifications in the ViewModel and submits a request to re-fetch more notifications. */
    func refreshNotifications() async {
      // if state != idle, there are existing notifications, leave them there while more are being fetched
      if case .idle = state {
        state = .loading
      }

      readOffset = 0
      unreadOffset = 0

      async let unreadResult = service.getUnreadNotifications(
        offset: 0,
        limit: limit
      )
      async let readResult = service.getReadNotificationWithSections(
        offset: 0,
        limit: limit
      )

      let (unreadRes, readRes) = await (unreadResult, readResult)

      switch (unreadRes, readRes) {
      case (.success(let unreadNotifications), .success(let readSectionData)):
        state = .loaded(readSectionData.sections, unreadNotifications)
        readOffset = readSectionData.sections.values.flatMap { $0 }.count
        unreadOffset = unreadNotifications.count
      case (.error(let error), _), (_, .error(let error)):
        state = .failed(error)
      }
    }

    func loadMoreNotifications() async {
      guard !isFetching else { return }
      isFetching = true
      defer { isFetching = false }

      let result = await service.getReadNotificationWithSections(
        offset: readOffset,
        limit: limit
      )

      switch result {
      case .success(let newSectionData):
        if case .loaded(let currentSections, let unreadNotifications) = state {
          var mergedSections = currentSections

          for (section, notifications) in newSectionData.sections {
            if let existingNotifications = mergedSections[section] {
              mergedSections[section] = existingNotifications + notifications
            } else {
              mergedSections[section] = notifications
            }
          }

          state = .loaded(mergedSections, unreadNotifications)
          readOffset += newSectionData.sections.values.flatMap { $0 }.count
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
            existingNotifications.insert(movedNotification, at: 0)
            updatedSections[section] = existingNotifications
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

    func markAllNotificationsAsRead() async {
      switch state {

      case .loaded(let sections, let unreadNotifications):
        var updatedSections = sections

        // Mark all notifications in sections as read
        for (section, notifications) in sections {
          let updatedNotifications = notifications.map { notification in
            var updated = notification
            updated.viewed = true
            return updated
          }
          updatedSections[section] = updatedNotifications
        }

        // Move all unread notifications to appropriate read sections
        for var unreadNotification in unreadNotifications {
          unreadNotification.viewed = true

          guard
            let date = sharedISO8601Formatter.date(
              from: unreadNotification.createdAt
            )
          else { continue }
          let section = date.notificationSection()

          if var existingNotifications = updatedSections[section] {
            // Check if notification already exists in this section to prevent duplicates
            if !existingNotifications.contains(where: {
              $0.notificationId == unreadNotification.notificationId
            }) {
              existingNotifications.insert(unreadNotification, at: 0)
              updatedSections[section] = existingNotifications
            }
          } else {
            updatedSections[section] = [unreadNotification]
          }
        }

        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.3)) {
            state = .loaded(updatedSections, [])
          }
        }

      default:
        return
      }

      let _ = await service.markAllNotificationsAsRead()
    }
  }
}
