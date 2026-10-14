import Foundation
import Testing

@testable import Splajompy

struct SessionHistoryServiceTests {
  init() {
    SessionHistoryService.clearSessionHistory()
  }

  @Test func sessionHistory_ReturnsCaughtUp() async throws {
    var isCaughtUp = SessionHistoryService.getCatchUpThreshold(feedType: .all)
    #expect(isCaughtUp == nil)

    SessionHistoryService.saveSessionHistory(
      feedType: .all,
      sessionStart: .now.addingTimeInterval(-8 * 60 * 60 * 24),
      sessionEnd: .now
    )

    isCaughtUp = SessionHistoryService.getCatchUpThreshold(feedType: .all)
    #expect(isCaughtUp != nil)
  }

  @Test func getSessionHistory_DoesNotCrossFeedTypes() async throws {
    SessionHistoryService.saveSessionHistory(
      feedType: .all, sessionStart: .now.addingTimeInterval(-8 * 60 * 60 * 24), sessionEnd: .now)
    SessionHistoryService.saveSessionHistory(
      feedType: .following, sessionStart: .now.addingTimeInterval(-3 * 60 * 60 * 24),
      sessionEnd: .now)

    #expect(SessionHistoryService.getCatchUpThreshold(feedType: .all) != nil)
    #expect(SessionHistoryService.getCatchUpThreshold(feedType: .following) == nil)
    #expect(SessionHistoryService.getCatchUpThreshold(feedType: .mutual) == nil)
  }

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
