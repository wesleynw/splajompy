import SwiftUI

class FeedRefreshManager: ObservableObject {
  @Published var refreshTrigger = false

  func triggerRefresh() {
    refreshTrigger.toggle()
  }
}
