import Foundation
import Testing

@testable import Splajompy

struct SessionHistoryServiceTests {
  @Test func deduplicateSessionHistory_NonOverlapping() async throws {
    let sessions = [
      Session(
        oldestTimestamp:
          Date.init(timeIntervalSinceNow: -60),
        newestTimestamp:
          Date.init(timeIntervalSinceNow: -50)
      ),
      Session(
        oldestTimestamp:
          Date.init(timeIntervalSinceNow: -40),
        newestTimestamp:
          Date.init(timeIntervalSinceNow: -30)
      ),
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 2)
  }

  @Test func deduplicateSessionHistory_NewerSessionOverlapsPartially()
    async throws
  {
    let date0 = Date.init(timeIntervalSinceNow: 0)
    let date1 = Date.init(timeIntervalSinceNow: 10)
    let date2 = Date.init(timeIntervalSinceNow: 20)
    let date3 = Date.init(timeIntervalSinceNow: 30)

    let sessions = [
      Session(
        oldestTimestamp:
          date1,
        newestTimestamp:
          date3
      ),
      Session(
        oldestTimestamp:
          date0,
        newestTimestamp:
          date2
      ),
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 1)
    #expect(deduped[0].oldestTimestamp == date0)
    #expect(deduped[0].newestTimestamp == date3)
  }

  @Test func deduplicateSessionHistory_SessionContainsSession()
    async throws
  {
    let date0 = Date.init(timeIntervalSinceNow: 0)
    let date1 = Date.init(timeIntervalSinceNow: 10)
    let date2 = Date.init(timeIntervalSinceNow: 20)
    let date3 = Date.init(timeIntervalSinceNow: 30)

    let sessions = [
      Session(
        oldestTimestamp:
          date0,
        newestTimestamp:
          date3
      ),
      Session(
        oldestTimestamp:
          date1,
        newestTimestamp:
          date2
      ),
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 1)
    #expect(deduped[0].oldestTimestamp == date0)
    #expect(deduped[0].newestTimestamp == date3)
  }
}
