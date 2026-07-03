import SwiftUI

struct PageTitle: ViewModifier {
  let title: String
  let placement: ToolbarItemPlacement
  let font: Font

  func body(content: Content) -> some View {
    content
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #else
        .navigationTitle("")
      #endif
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(macOS)
              .navigation
            #else
              placement
            #endif
          }()
        ) {
          Text(title)
            .font(font)
            .fixedSize()
        }
        .hideSharedBackgroundIfAvailable()
      }
  }
}
