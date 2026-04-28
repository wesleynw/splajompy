import SwiftUI

struct SupportedVersionViewModifier: ViewModifier {
  @State private var isShowingAlert: Bool = false
  func body(content: Content) -> some View {
    content
      .alert("Please update Splajompy", isPresented: $isShowingAlert) {
        Button("Update") {
          if let url = URL(
            string: "https://apps.apple.com/us/app/splajompy/id6744034321"
          ) {
            #if os(iOS)
              UIApplication.shared.open(url)
            #else
              NSWorkspace.shared.open(url)
            #endif
          }
        }
      } message: {
        Text("You are using an unsupported version of Splajompy.")
      }
      .onReceive(
        NotificationCenter.default.publisher(for: .userNeedsAppUpgrade)
      ) { _ in
        isShowingAlert = true
      }
  }
}
