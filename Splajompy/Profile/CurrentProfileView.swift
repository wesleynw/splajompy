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
      .toolbar {
        NavigationLink(
          destination: SettingsView()
        ) {
          Image(systemName: "gearshape")
        }
      }
    }
  }
}
