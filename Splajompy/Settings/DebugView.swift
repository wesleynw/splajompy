import SwiftUI

struct DebugView: View {
  @State private var sessionHistory: [Session] = []
  @State private var caughtUpThreshold: Date? = nil

  var body: some View {
    ScrollView {
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
        GridRow {
          Text("Oldest").bold()
          Text("Newest").bold()
        }
        Divider()
        ForEach(sessionHistory) { session in
          GridRow {
            Text(
              session.oldestTimestamp,
              format: .dateTime.month().day().hour().minute().second()
            )
            Text(
              session.newestTimestamp,
              format: .dateTime.month().day().hour().minute().second()
            )
          }
          .font(.system(.footnote, design: .monospaced))
        }
      }
      .padding()
    }
    .pageTitle("Debug")
    .onAppear {
      refresh()
    }
    .refreshable {
      refresh()
    }
  }

  private func refresh() {
    sessionHistory = SessionHistoryService.fetchSessionHistoryFromStorage(
      feedType: .all,
      defaults: UserDefaults.standard
    )
    caughtUpThreshold = SessionHistoryService.getCatchUpThreshold(
      feedType: .all
    )
  }
}
