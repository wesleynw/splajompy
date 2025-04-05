//
//  FeedRefreshManager.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/5/25.
//

import SwiftUI

class FeedRefreshManager: ObservableObject {
  @Published var refreshTrigger = false

  func triggerRefresh() {
    refreshTrigger.toggle()
  }
}
