import SwiftUI

struct CurrentProfileView: View {
  var postManager: PostStore
  @EnvironmentObject private var authManager: AuthManager

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
          destination: SettingsView().environmentObject(authManager)
        ) {
          Image(systemName: "gearshape")
        }
      }
    }
  }
}
