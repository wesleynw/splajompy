import Foundation

struct Session: Codable {
  var oldestTimestamp: Date
  var newestTimestamp: Date
}

struct SessionHistoryService {
  static let sessionStorageKey: String = "sessionHistoryMaps"

  static let thresholdDays: Int = -7

  /// Returns a timestamp after which the session is considered 'caught up'.
  static func getCatchUpThreshold(
    feedType: FeedType,
    defaults: UserDefaults = .standard
  ) -> Date? {
    let sessions = fetchSessionHistoryFromStorage(
      feedType: feedType,
      defaults: defaults
    )

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
  static func saveSessionHistory(
    feedType: FeedType,
    sessionStart: Date,
    sessionEnd: Date,
    defaults: UserDefaults = .standard
  ) {
    var currentSessions = fetchSessionHistoryFromStorage(
      feedType: feedType,
      defaults: defaults
    )

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

    persistSessionHistoryToStorage(
      feedType: feedType,
      sessions: deduplicateSessionHistory(sessions: currentSessions),
      defaults: defaults
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

  static func clearSessionHistory(defaults: UserDefaults = .standard) {
    for feedType in FeedType.allCases {
      persistSessionHistoryToStorage(
        feedType: feedType,
        sessions: [],
        defaults: defaults
      )
    }
  }

  static private func fetchSessionHistoryFromStorage(
    feedType: FeedType,
    defaults: UserDefaults
  )
    -> [Session]
  {
    guard
      let data = defaults.data(forKey: feedType.rawValue + sessionStorageKey),
      let sessions = try? JSONDecoder().decode([Session].self, from: data)
    else { return [] }
    return sessions
  }

  static private func persistSessionHistoryToStorage(
    feedType: FeedType,
    sessions: [Session],
    defaults: UserDefaults
  ) {
    if let jsonSessions = try? JSONEncoder().encode(sessions) {
      defaults.set(
        jsonSessions,
        forKey: feedType.rawValue + sessionStorageKey
      )
    }
  }
}
