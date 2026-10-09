import Foundation

struct Session: Codable {
  var oldestTimestamp: Date
  var newestTimestamp: Date
}

struct SessionHistoryService {
  static let sessionStorageKey: String = "sessionHistoryMaps"

  static let thresholdDays: Int = -7

  /// Returns a timestamp after which the session is considered 'caught up'.
  static func getCatchUpThreshold() -> Date? {
    let sessions = fetchSessionHistoryFromStorage()

    if let twoWeeksAgo = Calendar.current.date(
      byAdding: .day,
      value: thresholdDays,
      to: Date()
    ),
      let match = sessions.first(where: {
        $0.oldestTimestamp < twoWeeksAgo && $0.newestTimestamp > twoWeeksAgo
      })
    {
      return match.newestTimestamp
    }

    return nil
  }

  /// Persists the current session
  static func saveSessionHistory(sessionStart: Date, sessionEnd: Date) {
    var currentSessions = fetchSessionHistoryFromStorage()

    currentSessions.append(
      Session(oldestTimestamp: sessionStart, newestTimestamp: sessionEnd)
    )

    // filter out sessions ending before threshold
    if let thresholdDate = Calendar.current.date(
      byAdding: .day,
      value: thresholdDays,
      to: Date()
    ) {
      currentSessions = currentSessions.filter({
        $0.newestTimestamp > thresholdDate
      })
    }

    print("about to save sessions: \(currentSessions.debugDescription)")

    persistSessionHistoryToStorage(
      sessions: deduplicateSessionHistory(sessions: currentSessions)
    )
  }

  static func deduplicateSessionHistory(sessions: [Session]) -> [Session] {
    if sessions.count < 1 {
      return []
    }

    let sortedSessions = sessions.sorted {
      $0.oldestTimestamp < $1.oldestTimestamp
    }
    var output: [Session] = [sortedSessions[0]]

    for session in sortedSessions {
      let priorEnd = output.last!.newestTimestamp

      if session.oldestTimestamp <= priorEnd {
        output[output.count - 1].newestTimestamp = max(
          session.newestTimestamp,
          priorEnd
        )
      } else {
        output.append(session)
      }
    }

    return output
  }

  // TODO: set back to private
  static func fetchSessionHistoryFromStorage() -> [Session] {
    if let data = UserDefaults.standard.object(forKey: sessionStorageKey)
      as? Data,
      let sessions = try? JSONDecoder().decode([Session].self, from: data)
    {
      return sessions
    }

    return UserDefaults.standard.object(forKey: sessionStorageKey)
      as? [Session] ?? []
  }

  static private func persistSessionHistoryToStorage(sessions: [Session]) {
    print("saving sessions: \(sessions)")

    if let jsonSessions = try? JSONEncoder().encode(sessions) {
      UserDefaults.standard.set(jsonSessions, forKey: sessionStorageKey)
    }
  }
}
