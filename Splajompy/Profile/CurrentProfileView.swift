import SwiftUI

struct CurrentProfileView: View {
  @State private var path = NavigationPath()

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    let (userId, username) = authManager.getCurrentUser()

    NavigationStack(path: $path) {
      ProfileView(
        userId: userId,
        username: username,
        isOwnProfile: true
      )
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .profile(let id, let username):
          ProfileView(userId: Int(id)!, username: username)
  case .post(let id):
          StandalonePostView(postId: id)

        }
      }
      .onOpenURL { url in
        if let route = parseDeepLink(url) {
          path.append(route)
        }
      }
      .toolbar {
        NavigationLink(
          destination: SettingsView().environmentObject(authManager)
        ) {
          Image(systemName: "gearshape")
        }
      }
    }
  }
}
