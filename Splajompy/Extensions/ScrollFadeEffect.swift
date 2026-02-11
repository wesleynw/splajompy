import SwiftUI

#if os(iOS)
  @available(iOS 26, *)
  struct ScrollFadeEffect: ViewModifier {
    @Binding var scrollOffset: CGFloat

    func body(content: Content) -> some View {
      content
        .onScrollGeometryChange(for: CGFloat.self) { proxy in
          proxy.contentOffset.y + proxy.contentInsets.top
        } action: { _, offset in
          if offset >= 0 {
            scrollOffset = offset
          }
        }
    }
  }
#endif

extension View {
  @ViewBuilder
  func scrollFadeEffect(scrollOffset: Binding<CGFloat>) -> some View {
    #if os(iOS)
      if #available(iOS 26, *) {
        modifier(ScrollFadeEffect(scrollOffset: scrollOffset))
      } else {
        self
      }
    #else
      self
    #endif
  }

  @ViewBuilder
  func scrollFadeBackground(scrollOffset: CGFloat) -> some View {
    #if os(iOS)
      self.background(alignment: .top) {
        GeometryReader { geo in
          let topInsetHeight = geo.safeAreaInsets.top
          let visibleHeaderFraction = max(
            0, (topInsetHeight - scrollOffset) / max(0.7, topInsetHeight))
          Color.accentColor
            .opacity(visibleHeaderFraction)
            .offset(y: min(0, -scrollOffset))
            .ignoresSafeArea()
            .frame(height: 0)
        }
      }
    #else
      self
    #endif
  }
}
