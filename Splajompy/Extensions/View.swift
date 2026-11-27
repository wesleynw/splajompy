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
    placement: PageTitlePlacement = .center,
    font: Font = {
      #if os(iOS)
        SFont.sized(to: .callout, weight: .prominent)
      #else
        SFont.sized(to: .body, weight: .prominent)
      #endif
    }()
  ) -> some View {
    modifier(PageTitle(title: title, placement: placement, font: font))
  }
}
