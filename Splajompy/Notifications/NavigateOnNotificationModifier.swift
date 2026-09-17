import SwiftUI

// this is purely to respond to changes in the application delegate. because the UIKit and swiftui lifecycles
// aren't entirely synced up, it seems to require an .onAppear and .onChange, and I hate how messy it is, but
// it'll have to do for now.
//
// without the onAppear, the publisher fires from the app delegate before swiftui can attach an observer
// the same happens when using notificationcenter.push
struct NavigateOnNotificationModifier: ViewModifier {
  @Binding var pendingRoute: Route?

  var onRoute: (Route) -> Void

  func body(content: Content) -> some View {
    content
      .onAppear {
        if let route = pendingRoute {
          pendingRoute = nil
          onRoute(route)
        }
      }
      .onChange(of: pendingRoute) { _, newValue in
        if let route = newValue {
          pendingRoute = nil
          onRoute(route)
        }
      }
  }
}

@MainActor @Observable
class RoutingHelper {
  static let shared = RoutingHelper()

  var pendingRoute: Route? = nil
}
