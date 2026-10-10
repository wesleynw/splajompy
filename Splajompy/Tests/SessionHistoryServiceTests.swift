import Foundation
import Testing

@testable import Splajompy

struct SessionHistoryServiceTests {
  @Test func DeduplicateSessionHistory_NonOverlapping() async throws {
    let sessions = [
      [
        Date.init(timeIntervalSinceNow: -60),
        Date.init(timeIntervalSinceNow: -50),
      ],
      [
        Date.init(timeIntervalSinceNow: -40),
        Date.init(timeIntervalSinceNow: -30),
      ],
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 2)
  }

  @Test func DeduplicateSessionHistory_NewerSessionOverlapsPartially()
    async throws
  {
    let date0 = Date.init(timeIntervalSinceNow: 0)
    let date1 = Date.init(timeIntervalSinceNow: 10)
    let date2 = Date.init(timeIntervalSinceNow: 20)
    let date3 = Date.init(timeIntervalSinceNow: 30)

    let sessions = [
      [
        date1, date3,
      ],
      [
        date0, date2,
      ],
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 1)
    #expect(deduped[0].count == 2)
    #expect(deduped[0][0] == date0)
    #expect(deduped[0][1] == date3)
  }

  @Test func DeduplicateSessionHistory_SessionContainsSession()
    async throws
  {
    let date0 = Date.init(timeIntervalSinceNow: 0)
    let date1 = Date.init(timeIntervalSinceNow: 10)
    let date2 = Date.init(timeIntervalSinceNow: 20)
    let date3 = Date.init(timeIntervalSinceNow: 30)

    let sessions = [
      [
        date0, date3,
      ],
      [
        date1, date2,
      ],
    ]

    let deduped = SessionHistoryService.deduplicateSessionHistory(
      sessions: sessions
    )

    #expect(deduped.count == 1)
    #expect(deduped[0].count == 2)
    #expect(deduped[0][0] == date0)
    #expect(deduped[0][1] == date3)
  }
}
