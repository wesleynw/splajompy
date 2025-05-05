import SwiftUI

struct FeedContainerView: View {
  let feedType: FeedType
  let title: String

  @State private var path = NavigationPath()
  @State private var isShowingNewPostView = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    NavigationStack(path: $path) {
      FeedView(feedType: feedType)
        .toolbar {
          Button(
            "Post",
            systemImage: "plus",
            action: { isShowingNewPostView = true }
          )
          .labelStyle(.iconOnly)
        }
        .navigationTitle(title)
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .profile(let id, let username):
            ProfileView(userId: Int(id)!, username: username)
          }
        }
        .onOpenURL { url in
          print("on open url: \(url)")
          if let route = parseDeepLink(url) {
            path.append(route)
          }
        }
    }
    .sheet(isPresented: $isShowingNewPostView) {
      NewPostView(
        onPostCreated: { feedRefreshManager.triggerRefresh() }
      )
      .interactiveDismissDisabled()
    }
  }
}
