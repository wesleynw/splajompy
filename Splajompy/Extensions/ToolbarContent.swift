import SwiftUI

extension ToolbarContent {
  @ToolbarContentBuilder
  func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
    if #available(iOS 26, macOS 26, *) {
      self.sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
  }
}
