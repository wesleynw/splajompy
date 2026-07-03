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

  func pageTitle(
    _ title: String,
    placement: ToolbarItemPlacement = .principal,
    font: Font = SJFont.heading
  ) -> some View {
    modifier(PageTitle(title: title, placement: placement, font: font))
  }
}
