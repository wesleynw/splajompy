import SwiftUI

extension View {
  @ViewBuilder
  func modify(@ViewBuilder _ fn: (Self) -> (some View)?) -> some View {
    if let view = fn(self), !(view is EmptyView) {
      view
    } else {
      self
    }
  }

  /// Sets a navigation title that renders as a SwiftUI Text, inheriting `.fontDesign(.serif)`
  /// from the environment. On iOS the title is shown via a `.principal` toolbar item;
  /// `.navigationTitle` is still set for the back-button label and macOS rendering.
  func serifNavigationTitle(_ title: String) -> some View {
    self
      .navigationTitle(title)
      #if os(iOS)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text(title)
            .font(.headline)
          }
        }
      #endif
  }
}
