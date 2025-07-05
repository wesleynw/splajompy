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

    if calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
      return .thisWeek
    }

    let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
    let lastWeekEnd = calendar.date(
      byAdding: .day, value: -1,
      to: calendar.startOfDay(for: calendar.dateInterval(of: .weekOfYear, for: now)!.start))!

    if self
      >= calendar.startOfDay(for: calendar.dateInterval(of: .weekOfYear, for: lastWeekStart)!.start)
      && self <= calendar.startOfDay(for: lastWeekEnd).addingTimeInterval(86400 - 1)
    {
      return .lastWeek
    }

    return .older
  }
}
