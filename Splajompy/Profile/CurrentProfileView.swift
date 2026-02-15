import SwiftUI

struct CurrentProfileView: View {
  var postManager: PostStore
  @Environment(AuthManager.self) private var authManager

  var body: some View {
    if let currentUser = authManager.getCurrentUser() {
      ProfileView(
        userId: currentUser.userId,
        username: currentUser.username,
        postManager: postManager,
        isProfileTab: true
      )
      #if os(iOS)
        .toolbar {
          NavigationLink(value: SettingsRoute.settings) {
            Image(systemName: "gearshape")
          }
        }
      #endif
    }
  }
}
