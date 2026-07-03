import SwiftUI

enum PageTitlePlacement {
  case leading
  case center
}

struct PageTitle: ViewModifier {
  let title: String
  let placement: PageTitlePlacement
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
              switch placement {
              case .leading:
                .topBarLeading
              case .center:
                .principal
              }
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
