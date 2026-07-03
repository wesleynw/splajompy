import SwiftUI

extension ToolbarContent {
  @ToolbarContentBuilder
  func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
    if #available(macOS 26.0, *) {
      self.sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
  }
}
