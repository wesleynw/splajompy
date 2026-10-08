import Foundation

struct SessionHistoryService {
  static let sessionStorageKey: String = "sessionHistoryMaps"

  /// Returns a timestamp after which the session is considered 'caught up'.
  static func getCatchUpThreshold() -> Date? {
    let sessions = fetchSessionHistoryFromStorage()

    if let twoWeeksAgo = Calendar.current.date(
      byAdding: .day,
      value: -2,
      to: Date()
    ),
      let match = sessions.first(where: {
        $0.count > 1 && $0[0] > twoWeeksAgo && $0[1] < twoWeeksAgo
      })
    {
      print("found caught up threshold, \(match[0])")
      return match[0]
    }

    print("no caught up threshold")
    return nil
  }

  /// Persists the current session
  static func saveSessionHistory(sessionStart: Date, sessionEnd: Date) {
    var currentSessions = fetchSessionHistoryFromStorage()

    currentSessions.append([sessionStart, sessionEnd])

    // delete sessions older than threshold
    if let twoDaysAgo = Calendar.current.date(
      byAdding: .day,
      value: -2,
      to: Date()
    ) {
      currentSessions = currentSessions.filter({
        $0.count > 1
          && $0[0] > twoDaysAgo
      })
    }

    persistSessionHistoryToStorage(
      sessions: deduplicateSessionHistory(sessions: currentSessions)
    )
  }

  static private func deduplicateSessionHistory(sessions: [[Date]]) -> [[Date]] {
    let sortedSessions = sessions.sorted { $0[0] < $1[0] }
    var output: [[Date]] = [sortedSessions[0]]

    for session in sortedSessions {
      let start = session[0]
      let end = session[1]
      let priorStart = output.last![0]
      let priorEnd = output.last![1]

      if start > priorStart || end < priorEnd {
        output[output.count - 1][0] = max(start, priorStart)
        output[output.count - 1][1] = min(end, priorEnd)
      } else {
        output.append([start, end])
      }
    }

    return output
  }

  // TODO: set back to private
  static func fetchSessionHistoryFromStorage() -> [[Date]] {
    return UserDefaults.standard.object(forKey: sessionStorageKey)
      as? [[Date]] ?? []
  }

  static private func persistSessionHistoryToStorage(sessions: [[Date]]) {
    print("saving sessions: \(sessions)")

    UserDefaults.standard.set(sessions, forKey: sessionStorageKey)
  }
}
