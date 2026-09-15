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
        .toolbar {
          ToolbarItem(
            placement: {
              switch placement {
              case .leading:
                .topBarLeading
              case .center:
                .principal
              }
            }()
          ) {
            Text(title)
            .font(font)
            .fixedSize()
          }
          .hideSharedBackgroundIfAvailable()
        }
      #else
        .navigationTitle(title)
      #endif
  }
}
