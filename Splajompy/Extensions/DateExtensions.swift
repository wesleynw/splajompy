import Foundation

enum NotificationDateSection: String, CaseIterable, Decodable, Hashable {
  case today = "Today"
  case yesterday = "Yesterday"
  case thisWeek = "This Week"
  case lastWeek = "Last Week"
  case older = "Older"
}

nonisolated(unsafe) let sharedISO8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

@MainActor let sharedRelativeDateTimeFormatter: RelativeDateTimeFormatter = {
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .full
  return formatter
}()

extension Date {
  func notificationSection() -> NotificationDateSection {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(self) {
      return .today
    }

    if calendar.isDateInYesterday(self) {
      return .yesterday
    }

    let daysBetween =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: now)
      ).day ?? 0

    if daysBetween >= 2 && daysBetween <= 7 {
      return .thisWeek
    }

    if daysBetween >= 8 && daysBetween <= 14 {
      return .lastWeek
    }

    return .older
  }
}
