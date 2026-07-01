import SwiftUI

struct PageTitle: ViewModifier {
  let title: String

  func body(content: Content) -> some View {
    content
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(title)
            .font(SJFont.heading)
        }
      }
  }
}
